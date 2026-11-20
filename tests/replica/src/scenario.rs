//! Scenario files and the run that drives both engines through one.
//!
//! A scenario is a sequence of steps, each opened by a header line.
//!
//! - `--! server` opens PostgreSQL run as the superuser in one transaction,
//!   for what only the server's own roles write. The session holds the
//!   `tests/fixture.sql` helpers.
//! - `--! client user=<uuid> expect=ok` opens SQLite statements one
//!   principal's client runs in one transaction. Besides `user` a header may
//!   name `installation`, `original`, `links` and `email`, the other
//!   [`crate::SETTINGS`]. `expect` is `ok` or the SQLSTATE both engines
//!   refuse with. `upload=<SQLSTATE>` in its place is a write the replica
//!   accepts and the server refuses at upload, after which the client reverts
//!   to the server's rows. `diverges=grants,memberships` names tables whose
//!   rows the replica may show otherwise than PostgreSQL until the server's
//!   rows arrive.
//!
//! A client writes a `uuid` as the 16-byte blob the replica stores, such as
//! `X'10000000000070008000000000000001'`, the form a bound value takes. A
//! header names it in its text form, as the session setting holds it.
//!
//! Other lines starting with `--` are comments.

use std::{
    fmt,
    path::{Path, PathBuf},
};

use sqlparser::{dialect::SQLiteDialect, parser::Parser};

use crate::{
    HarnessError, Mismatch, Moment, Principal, Replica, SERVER_DERIVED_TABLES, Server, TRANSLATION,
    TableShape, Verdict,
};

/// One step of a scenario.
#[derive(Debug, Clone)]
pub enum Step {
    /// What the server's own roles write.
    Server {
        /// The header's line.
        line: usize,
        /// The PostgreSQL to run.
        sql: String,
    },
    /// What one principal's client writes.
    Client {
        /// The header's line.
        line: usize,
        /// Whose client.
        principal: Principal,
        /// What the two engines answer.
        expect: Outcome,
        /// The tables whose rows may differ until the server's rows arrive.
        diverges: Vec<String>,
        /// The SQLite statements.
        sql: String,
    },
}

/// What the two engines answer a client step's write.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    /// Both engines accept the write.
    Accepted,
    /// Both engines refuse the write with this SQLSTATE.
    Refused(String),
    /// The replica accepts the write and the server refuses its upload with
    /// this SQLSTATE, so the client reverts it.
    RefusedAtUpload(String),
}

impl fmt::Display for Outcome {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Accepted => formatter.write_str("ok"),
            Self::Refused(sqlstate) => formatter.write_str(sqlstate),
            Self::RefusedAtUpload(sqlstate) => write!(formatter, "{sqlstate} at upload"),
        }
    }
}

impl Step {
    /// The header's line.
    #[must_use]
    pub fn line(&self) -> usize {
        match self {
            Self::Server { line, .. } | Self::Client { line, .. } => *line,
        }
    }
}

/// A scenario file.
#[derive(Debug, Clone)]
pub struct Scenario {
    /// The file.
    pub path: PathBuf,
    /// The file name without its extension.
    pub name: String,
    /// The steps, in file order.
    pub steps: Vec<Step>,
}

/// The first disagreement a scenario found, at the step it found it.
#[derive(Debug)]
pub struct Failure {
    /// The scenario file.
    pub path: PathBuf,
    /// The step's header line.
    pub line: usize,
    /// The disagreement.
    pub mismatch: Mismatch,
}

impl fmt::Display for Failure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "{}:{}: {}",
            self.path.display(),
            self.line,
            self.mismatch
        )
    }
}

impl Scenario {
    /// Reads the scenario at `path`.
    ///
    /// # Errors
    ///
    /// Returns an error when the file cannot be read or is malformed.
    pub fn load(path: &Path) -> Result<Self, HarnessError> {
        let text = std::fs::read_to_string(path).map_err(|source| HarnessError::Io {
            path: path.display().to_string(),
            source,
        })?;
        let malformed = |line: usize, reason: String| HarnessError::Scenario {
            path: path.display().to_string(),
            line,
            reason,
        };
        let mut steps = Vec::new();
        let mut body = String::new();
        let mut header: Option<(usize, &str)> = None;
        for (index, line) in text
            .lines()
            .enumerate()
            .chain(std::iter::once((usize::MAX, "--! end")))
        {
            let number = index.wrapping_add(1);
            if let Some(rest) = line.strip_prefix("--!") {
                if let Some((header_line, header_text)) = header.take() {
                    steps.push(
                        parse_step(header_line, header_text, std::mem::take(&mut body))
                            .map_err(|reason| malformed(header_line, reason))?,
                    );
                }
                header = Some((number, rest.trim()));
            } else if !line.trim_start().starts_with("--") && !line.trim().is_empty() {
                if header.is_none() {
                    return Err(malformed(
                        number,
                        "a statement before the first step".into(),
                    ));
                }
                body.push_str(line);
                body.push('\n');
            }
        }
        let name = path
            .file_stem()
            .map_or_else(String::new, |stem| stem.to_string_lossy().into_owned());
        Ok(Self {
            path: path.to_owned(),
            name,
            steps,
        })
    }

    /// Every scenario under `tests/replica/scenarios`, by file name.
    ///
    /// # Errors
    ///
    /// Returns an error when a scenario cannot be read or is malformed.
    pub fn all() -> Result<Vec<Self>, HarnessError> {
        let directory = Path::new(env!("CARGO_MANIFEST_DIR")).join("scenarios");
        let entries = std::fs::read_dir(&directory).map_err(|source| HarnessError::Io {
            path: directory.display().to_string(),
            source,
        })?;
        let mut paths = Vec::new();
        for entry in entries {
            let path = entry
                .map_err(|source| HarnessError::Io {
                    path: directory.display().to_string(),
                    source,
                })?
                .path();
            if path.extension().is_some_and(|extension| extension == "sql") {
                paths.push(path);
            }
        }
        paths.sort();
        paths.iter().map(|path| Self::load(path)).collect()
    }

    /// Drives a fresh PostgreSQL database and one replica per principal
    /// through every step, answering the first disagreement.
    ///
    /// # Errors
    ///
    /// Returns an error when the harness itself fails, a server step
    /// included.
    pub fn run(&self) -> Result<Option<Failure>, HarnessError> {
        let mut server = Server::create(&format!("replica_{}", self.name))?;
        let shapes = server.shapes().to_vec();
        let mut replicas: Vec<Replica> = Vec::new();
        for step in &self.steps {
            let failure = |mismatch| {
                Ok(Some(Failure {
                    path: self.path.clone(),
                    line: step.line(),
                    mismatch,
                }))
            };
            let mismatch = match step {
                Step::Server { sql, .. } => {
                    server.execute(sql)?;
                    synchronize(&mut server, &mut replicas, &shapes)?
                }
                Step::Client {
                    principal,
                    expect,
                    diverges,
                    sql,
                    ..
                } => {
                    let known = replicas
                        .iter()
                        .position(|replica| replica.principal() == principal);
                    let index = if let Some(index) = known {
                        index
                    } else {
                        let mut replica = Replica::new(principal)?;
                        if let Some(mismatch) = deliver(&mut server, &mut replica, &shapes)? {
                            return failure(mismatch);
                        }
                        replicas.push(replica);
                        replicas.len() - 1
                    };
                    let (sqlite, postgres) = statements(&self.path, step.line(), sql)?;
                    let server_verdict = server.write(principal, &postgres)?;
                    let expected = match (expect, &server_verdict) {
                        (Outcome::Accepted, Verdict::Accepted) => true,
                        (
                            Outcome::Refused(code) | Outcome::RefusedAtUpload(code),
                            Verdict::Refused { sqlstate, .. },
                        ) => code == sqlstate,
                        _ => false,
                    };
                    if !expected {
                        return failure(Mismatch::Expectation {
                            expected: expect.to_string(),
                            actual: server_verdict,
                        });
                    }
                    let replica = &mut replicas[index];
                    let replica_verdict = replica.write(&sqlite)?;
                    let agrees = match expect {
                        Outcome::RefusedAtUpload(_) => replica_verdict == Verdict::Accepted,
                        Outcome::Accepted | Outcome::Refused(_) => {
                            replica_verdict.agrees_with(&server_verdict)
                        }
                    };
                    if !agrees {
                        return failure(Mismatch::Verdict {
                            replica: replica_verdict,
                            server: server_verdict,
                        });
                    }
                    match expect {
                        Outcome::Accepted => {
                            let compared = shapes.iter().filter(|shape| {
                                !SERVER_DERIVED_TABLES.contains(&shape.logical.as_str())
                                    && !diverges.contains(&shape.logical)
                            });
                            if let Some(mismatch) =
                                compare(&mut server, replica, compared, Moment::BeforeSync)?
                            {
                                return failure(mismatch);
                            }
                            synchronize(&mut server, &mut replicas, &shapes)?
                        }
                        // Delivering the server's rows reverts the write the
                        // server refused, as the client does on a rejection.
                        Outcome::RefusedAtUpload(_) => {
                            synchronize(&mut server, &mut replicas, &shapes)?
                        }
                        Outcome::Refused(_) => None,
                    }
                }
            };
            if let Some(mismatch) = mismatch {
                return failure(mismatch);
            }
        }
        Ok(None)
    }
}

/// Parses one step from its header text after `--!` and its body.
fn parse_step(line: usize, header: &str, sql: String) -> Result<Step, String> {
    let mut words = header.split_whitespace();
    match words.next() {
        Some("server") => {
            if let Some(word) = words.next() {
                return Err(format!("a server step takes no `{word}`"));
            }
            Ok(Step::Server { line, sql })
        }
        Some("client") => {
            let mut expect = None;
            let mut diverges = Vec::new();
            let mut settings = Vec::new();
            for word in words {
                let (key, value) = word
                    .split_once('=')
                    .ok_or_else(|| format!("`{word}` is no key=value"))?;
                let outcome = match (key, value) {
                    ("expect", "ok") => Outcome::Accepted,
                    ("expect", sqlstate) => Outcome::Refused(sqlstate.to_owned()),
                    ("upload", "ok") => {
                        return Err("`upload=` names the SQLSTATE the server refuses with".into());
                    }
                    ("upload", sqlstate) => Outcome::RefusedAtUpload(sqlstate.to_owned()),
                    ("diverges", tables) => {
                        diverges.extend(tables.split(',').map(str::to_owned));
                        continue;
                    }
                    _ => {
                        settings.push((key, value));
                        continue;
                    }
                };
                if expect.replace(outcome).is_some() {
                    return Err("a client step takes one `expect=` or `upload=`".into());
                }
            }
            let principal =
                Principal::new(settings).map_err(|key| format!("`{key}` names no setting"))?;
            let expect =
                expect.ok_or_else(|| "a client step needs `expect=` or `upload=`".to_owned())?;
            Ok(Step::Client {
                line,
                principal,
                expect,
                diverges,
                sql,
            })
        }
        Some("end") => Err("`--! end` is reserved".into()),
        other => Err(format!("unknown step `{}`", other.unwrap_or_default())),
    }
}

/// The SQLite statements of a client step and their reverse translations.
fn statements(
    path: &Path,
    line: usize,
    sql: &str,
) -> Result<(Vec<String>, Vec<String>), HarnessError> {
    let parsed =
        Parser::parse_sql(&SQLiteDialect {}, sql).map_err(|error| HarnessError::Scenario {
            path: path.display().to_string(),
            line,
            reason: format!("the client statements do not parse as SQLite: {error}"),
        })?;
    let mut sqlite = Vec::new();
    let mut postgres = Vec::new();
    for statement in parsed {
        let reversed = TRANSLATION
            .translator
            .reverse_translate(&statement, &TRANSLATION.schema, &TRANSLATION.query_options)
            .map_err(|source| HarnessError::Translation {
                context: format!("{}:{line}: reverse translating {statement}", path.display()),
                source: Box::new(source),
            })?;
        sqlite.push(statement.to_string());
        postgres.push(reversed.to_string());
    }
    Ok((sqlite, postgres))
}

/// Delivers to `replica` the rows its principal reads on the server.
fn deliver(
    server: &mut Server,
    replica: &mut Replica,
    shapes: &[TableShape],
) -> Result<Option<Mismatch>, HarnessError> {
    let mut delivered = Vec::new();
    for shape in shapes {
        delivered.push((shape, server.delivery(replica.principal(), shape)?));
    }
    Ok(replica
        .deliver(&delivered)?
        .map(|message| Mismatch::Delivery {
            principal: replica.principal().clone(),
            message,
        }))
}

/// Delivers the server's rows to every replica, then compares every view and
/// runs both PRAGMA checks.
fn synchronize(
    server: &mut Server,
    replicas: &mut [Replica],
    shapes: &[TableShape],
) -> Result<Option<Mismatch>, HarnessError> {
    for replica in replicas.iter_mut() {
        if let Some(mismatch) = deliver(server, replica, shapes)? {
            return Ok(Some(mismatch));
        }
        if let Some(mismatch) = compare(server, replica, shapes.iter(), Moment::AfterSync)? {
            return Ok(Some(mismatch));
        }
        if let Some((check, problems)) = replica.integrity()?.into_iter().next() {
            return Ok(Some(Mismatch::Integrity {
                principal: replica.principal().clone(),
                check,
                problems,
            }));
        }
    }
    Ok(None)
}

/// Compares each view of `shapes` on `replica` with what its principal reads
/// on the server.
fn compare<'a>(
    server: &mut Server,
    replica: &mut Replica,
    shapes: impl Iterator<Item = &'a TableShape>,
    moment: Moment,
) -> Result<Option<Mismatch>, HarnessError> {
    for shape in shapes {
        let replica_rows = replica.rows(shape)?;
        let server_rows = server.rows(replica.principal(), shape, &replica_rows.columns)?;
        if !replica_rows.same_as(&server_rows, shape) {
            return Ok(Some(Mismatch::Rows {
                principal: replica.principal().clone(),
                moment,
                replica: replica_rows,
                server: server_rows,
            }));
        }
    }
    Ok(None)
}
