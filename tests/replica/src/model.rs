//! What the two engines are compared on.

use std::{collections::BTreeSet, fmt};

use thiserror::Error;

use crate::{HarnessError, SETTINGS};

/// The session settings one request runs under, every one of [`SETTINGS`]
/// present and the unset ones empty, as `pg_temp.act` leaves them.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Principal {
    values: Vec<(&'static str, String)>,
}

impl Principal {
    /// A principal holding `values`, each a scenario key such as `user` with
    /// its value.
    ///
    /// # Errors
    ///
    /// Returns the key when it names none of [`SETTINGS`].
    pub fn new<'a>(values: impl IntoIterator<Item = (&'a str, &'a str)>) -> Result<Self, String> {
        let mut settings: Vec<(&'static str, String)> = SETTINGS
            .iter()
            .map(|(_, setting)| (*setting, String::new()))
            .collect();
        for (key, value) in values {
            let index = SETTINGS
                .iter()
                .position(|(name, _)| *name == key)
                .ok_or_else(|| key.to_owned())?;
            value.clone_into(&mut settings[index].1);
        }
        Ok(Self { values: settings })
    }

    /// Each setting with its value, empty when unset.
    pub fn settings(&self) -> impl Iterator<Item = (&'static str, &str)> {
        self.values
            .iter()
            .map(|(setting, value)| (*setting, value.as_str()))
    }

    /// The value of `setting`, empty when unset.
    #[must_use]
    pub fn value(&self, setting: &str) -> &str {
        self.settings()
            .find(|(name, _)| *name == setting)
            .map_or("", |(_, value)| value)
    }
}

impl fmt::Display for Principal {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut first = true;
        for (key, setting) in SETTINGS {
            let value = self.value(setting);
            if !value.is_empty() {
                if !first {
                    formatter.write_str(" ")?;
                }
                write!(formatter, "{key}={value}")?;
                first = false;
            }
        }
        if first {
            formatter.write_str("anonymous")?;
        }
        Ok(())
    }
}

/// How an engine answered one transaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Verdict {
    /// Every statement ran and the transaction committed.
    Accepted,
    /// A statement or the commit failed and the transaction rolled back.
    Refused {
        /// The SQLSTATE PostgreSQL reports, read back from SQLite's message
        /// on the replica.
        sqlstate: String,
        /// The engine's message.
        message: String,
    },
}

impl Verdict {
    /// Whether `self` and `other` agree, the same SQLSTATE for two refusals.
    #[must_use]
    pub fn agrees_with(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::Accepted, Self::Accepted) => true,
            (
                Self::Refused { sqlstate: left, .. },
                Self::Refused {
                    sqlstate: right, ..
                },
            ) => left == right,
            _ => false,
        }
    }
}

impl fmt::Display for Verdict {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Accepted => formatter.write_str("accepted"),
            Self::Refused { sqlstate, message } => {
                write!(formatter, "refused {sqlstate} ({message})")
            }
        }
    }
}

/// What a column holds, where the harness reads it differently.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ColumnKind {
    /// A `timestamptz`, which each engine stamps from its own clock.
    Timestamp,
    /// A `bytea`, a `BLOB` on the replica.
    Bytes,
    /// A `uuid`, a 16-byte `BLOB` on the replica, compared as its 32 hex
    /// digits.
    Uuid,
    /// A `jsonb`, held on the replica as the text PostgreSQL prints.
    Jsonb,
    /// Anything else, whose JSON value both engines agree on.
    Other,
}

/// One table the replica holds, as both engines name it.
#[derive(Debug, Clone)]
pub struct TableShape {
    /// The name the client reads and writes, the PostgreSQL table.
    pub logical: String,
    /// The replica table that stores the rows.
    pub physical: String,
    /// Each stored column with its kind, in declaration order.
    pub columns: Vec<(String, ColumnKind)>,
    /// The generated columns, which each engine computes from the row itself.
    pub generated: BTreeSet<String>,
}

impl TableShape {
    /// The kind of `column`.
    #[must_use]
    pub fn kind(&self, column: &str) -> ColumnKind {
        self.columns
            .iter()
            .find(|(name, _)| name == column)
            .map_or(ColumnKind::Other, |(_, kind)| *kind)
    }

    /// The columns a delivery carries, every stored column but the generated
    /// ones, in declaration order.
    pub fn delivered(&self) -> impl Iterator<Item = &(String, ColumnKind)> {
        self.columns
            .iter()
            .filter(|(name, _)| !self.generated.contains(name))
    }
}

/// One text column read back from either engine.
#[derive(diesel::QueryableByName)]
pub(crate) struct Line {
    /// The text.
    #[diesel(sql_type = diesel::sql_types::Text)]
    pub(crate) line: String,
}

/// `name` as a quoted identifier, which both engines read.
pub(crate) fn quote(name: &str) -> String {
    format!("\"{}\"", name.replace('"', "\"\""))
}

/// The cells of one row of `table`, read from the JSON array an engine
/// printed it as.
pub(crate) fn cells(table: &str, line: &str) -> Result<Vec<Cell>, HarnessError> {
    let values: Vec<serde_json::Value> =
        serde_json::from_str(line).map_err(|source| HarnessError::Rows {
            table: table.to_owned(),
            source,
        })?;
    Ok(values
        .into_iter()
        .map(|value| match value {
            serde_json::Value::Null => None,
            serde_json::Value::Bool(value) => Some(if value { "1" } else { "0" }.to_owned()),
            serde_json::Value::String(value) => Some(value),
            other => Some(other.to_string()),
        })
        .collect())
}

/// One value as both engines are compared on it, `None` for `NULL`.
pub type Cell = Option<String>;

/// The rows one view shows, over the columns it exposes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ViewRows {
    /// The view.
    pub table: String,
    /// The columns the replica's view exposes.
    pub columns: Vec<String>,
    /// The rows, sorted.
    pub rows: Vec<Vec<Cell>>,
}

/// How far apart two clocks may stamp the same write, in seconds.
pub const CLOCK_SKEW_SECONDS: f64 = 5.0;

impl ViewRows {
    /// Whether `self` and `other` hold the same rows, timestamps within
    /// [`CLOCK_SKEW_SECONDS`] of each other.
    #[must_use]
    pub fn same_as(&self, other: &Self, shape: &TableShape) -> bool {
        let timestamps: Vec<bool> = self
            .columns
            .iter()
            .map(|column| shape.kind(column) == ColumnKind::Timestamp)
            .collect();
        let key = |row: &[Cell]| -> Vec<Cell> {
            row.iter()
                .zip(&timestamps)
                .map(|(cell, timestamp)| if *timestamp { None } else { cell.clone() })
                .collect()
        };
        let mut left = self.rows.clone();
        let mut right = other.rows.clone();
        left.sort_by_key(|row| key(row));
        right.sort_by_key(|row| key(row));
        left.len() == right.len()
            && left.iter().zip(&right).all(|(left, right)| {
                left.iter()
                    .zip(right)
                    .zip(&timestamps)
                    .all(|((left, right), timestamp)| {
                        if *timestamp {
                            same_instant(left, right)
                        } else {
                            left == right
                        }
                    })
            })
    }
}

/// Whether two timestamps, each an epoch in seconds or `infinity` or
/// `-infinity`, name instants [`CLOCK_SKEW_SECONDS`] apart at most.
fn same_instant(left: &Cell, right: &Cell) -> bool {
    match (left, right) {
        (Some(left), Some(right)) => match (left.parse::<f64>(), right.parse::<f64>()) {
            (Ok(left), Ok(right)) if left.is_finite() && right.is_finite() => {
                (left - right).abs() <= CLOCK_SKEW_SECONDS
            }
            _ => left == right,
        },
        (left, right) => left == right,
    }
}

impl fmt::Display for ViewRows {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(
            formatter,
            "    {} ({})",
            self.table,
            self.columns.join(", ")
        )?;
        for row in &self.rows {
            let cells: Vec<&str> = row
                .iter()
                .map(|cell| cell.as_deref().unwrap_or("NULL"))
                .collect();
            writeln!(formatter, "      {}", cells.join(" | "))?;
        }
        Ok(())
    }
}

/// When during a step the rows were compared.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Moment {
    /// After the replica ran the client's write itself, before the server's
    /// rows arrived.
    BeforeSync,
    /// After the replica received the rows its principal reads on the server.
    AfterSync,
}

impl fmt::Display for Moment {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::BeforeSync => "before sync",
            Self::AfterSync => "after sync",
        })
    }
}

/// A disagreement a scenario step found.
#[derive(Debug, Error)]
pub enum Mismatch {
    /// PostgreSQL did not answer as the scenario says it does.
    #[error("PostgreSQL {actual}, the scenario expects {expected}")]
    Expectation {
        /// What the scenario expects.
        expected: String,
        /// What PostgreSQL did.
        actual: Verdict,
    },
    /// The replica answered otherwise than PostgreSQL.
    #[error("the replica {replica}, PostgreSQL {server}")]
    Verdict {
        /// The replica's answer.
        replica: Verdict,
        /// PostgreSQL's answer.
        server: Verdict,
    },
    /// A view shows the principal other rows than PostgreSQL does.
    #[error("{principal} reads other rows {moment}\n  replica:\n{replica}  PostgreSQL:\n{server}")]
    Rows {
        /// Whose replica.
        principal: Principal,
        /// When.
        moment: Moment,
        /// What the replica shows.
        replica: ViewRows,
        /// What PostgreSQL shows.
        server: ViewRows,
    },
    /// A PRAGMA check failed on a replica.
    #[error("{principal}'s replica fails {check}: {problems:?}")]
    Integrity {
        /// Whose replica.
        principal: Principal,
        /// The PRAGMA.
        check: &'static str,
        /// What it reported.
        problems: Vec<String>,
    },
    /// The replica refused the rows the server delivered.
    #[error("{principal}'s replica refuses the delivered rows: {message}")]
    Delivery {
        /// Whose replica.
        principal: Principal,
        /// SQLite's message.
        message: String,
    },
}
