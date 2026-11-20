//! The PostgreSQL side, one database per scenario cloned from the template
//! `tests/run.sh` builds.

use std::collections::BTreeSet;

use diesel::{
    Connection, PgConnection, RunQueryDsl,
    connection::SimpleConnection,
    result::Error as DieselError,
    sql_types::{Bool, Text},
};

use crate::{
    ACTING_ROLE, ColumnKind, HarnessError, Principal, TRANSLATION, TableShape, Verdict, ViewRows,
    error::Context,
    model::{Line, cells, quote},
    root,
};

diesel::define_sql_function! {
    /// Sets a session setting, for the transaction alone when `is_local`.
    fn set_config(setting_name: Text, new_value: Text, is_local: Bool) -> Text;
}

/// The database every scenario database is cloned from.
const TEMPLATE: &str = "schema_template";

/// One scenario's PostgreSQL database, holding the `tests/fixture.sql`
/// helpers in its session.
pub struct Server {
    connection: PgConnection,
    shapes: Vec<TableShape>,
    readable: BTreeSet<String>,
}

/// Opens a connection to `url`.
fn connect(url: &str) -> Result<PgConnection, HarnessError> {
    PgConnection::establish(url).map_err(|source| HarnessError::Connection {
        target: url.to_owned(),
        source,
    })
}

impl Server {
    /// A fresh database named `name`, cloned from the template.
    ///
    /// # Errors
    ///
    /// Returns an error when `REPLICA_DATABASE_URL` is unset or PostgreSQL
    /// refuses to create or read the database.
    pub fn create(name: &str) -> Result<Self, HarnessError> {
        let base =
            std::env::var("REPLICA_DATABASE_URL").map_err(|_| HarnessError::MissingDatabaseUrl)?;
        let mut admin = connect(&format!("{base}/postgres"))?;
        admin
            .batch_execute(&format!("DROP DATABASE IF EXISTS {}", quote(name)))
            .context(|| format!("dropping {name}"))?;
        admin
            .batch_execute(&format!(
                "CREATE DATABASE {} TEMPLATE {TEMPLATE}",
                quote(name)
            ))
            .context(|| format!("creating {name}"))?;
        let mut connection = connect(&format!("{base}/{name}"))?;
        let fixture_path = root().join("tests/fixture.sql");
        let fixture =
            std::fs::read_to_string(&fixture_path).map_err(|source| HarnessError::Io {
                path: fixture_path.display().to_string(),
                source,
            })?;
        connection
            .batch_execute("SET search_path = public")
            .and_then(|()| connection.batch_execute(&fixture))
            .context(|| "loading tests/fixture.sql".into())?;
        let mut shapes = Vec::new();
        let mut readable = BTreeSet::new();
        for entry in &TRANSLATION.manifest {
            // The catalog rows of a table known only at run time.
            let types: Line = diesel::sql_query(
                "SELECT coalesce(json_agg(json_build_array(attname, format_type(atttypid, atttypmod), \
                 attgenerated <> '') ORDER BY attnum), '[]')::text AS line FROM pg_attribute \
                 WHERE attrelid = to_regclass($1) AND attnum > 0 AND NOT attisdropped",
            )
            .bind::<Text, _>(&entry.logical)
            .get_result(&mut connection)
            .context(|| format!("reading the columns of {}", entry.logical))?;
            let types: Vec<(String, String, bool)> =
                serde_json::from_str(&types.line).map_err(|source| HarnessError::Rows {
                    table: entry.logical.clone(),
                    source,
                })?;
            let kind = |column: &str| match types
                .iter()
                .find(|(name, _, _)| name == column)
                .map(|(_, kind, _)| kind.as_str())
            {
                Some("timestamp with time zone") => ColumnKind::Timestamp,
                Some("bytea") => ColumnKind::Bytes,
                Some("jsonb") => ColumnKind::Jsonb,
                _ => ColumnKind::Other,
            };
            shapes.push(TableShape {
                logical: entry.logical.clone(),
                physical: entry.physical.clone(),
                columns: entry
                    .columns
                    .iter()
                    .map(|column| (column.name.clone(), kind(&column.name)))
                    .collect(),
                generated: types
                    .iter()
                    .filter(|(_, _, generated)| *generated)
                    .map(|(name, _, _)| name.clone())
                    .collect(),
            });
            let privilege: Line = diesel::sql_query(
                "SELECT has_table_privilege($1, to_regclass($2), 'SELECT')::text AS line",
            )
            .bind::<Text, _>(ACTING_ROLE)
            .bind::<Text, _>(&entry.logical)
            .get_result(&mut connection)
            .context(|| format!("reading whether {ACTING_ROLE} reads {}", entry.logical))?;
            if privilege.line == "true" {
                readable.insert(entry.logical.clone());
            }
        }
        Ok(Self {
            connection,
            shapes,
            readable,
        })
    }

    /// Each table the replica holds.
    #[must_use]
    pub fn shapes(&self) -> &[TableShape] {
        &self.shapes
    }

    /// Runs `sql` as the superuser in one transaction, as the server's own
    /// roles write.
    ///
    /// # Errors
    ///
    /// Returns an error when PostgreSQL refuses `sql`.
    pub fn execute(&mut self, sql: &str) -> Result<(), HarnessError> {
        let outcome = self
            .connection
            .batch_execute(&format!("BEGIN;\n{sql}\n;COMMIT"));
        if outcome.is_err() {
            self.connection
                .batch_execute("ROLLBACK")
                .context(|| "rolling back a server step".into())?;
        }
        outcome
            .and_then(|()| self.connection.batch_execute("RESET ROLE"))
            .context(|| format!("running the server step\n{sql}"))
    }

    /// Opens a transaction running as [`ACTING_ROLE`] under the settings of
    /// `principal`.
    fn act(&mut self, principal: &Principal) -> diesel::QueryResult<()> {
        self.connection
            .batch_execute(&format!("BEGIN; SET LOCAL ROLE {ACTING_ROLE}"))?;
        for (setting, value) in principal.settings() {
            diesel::select(set_config(setting, value, true)).execute(&mut self.connection)?;
        }
        Ok(())
    }

    /// Runs the reverse-translated `statements` as `principal` in one
    /// transaction.
    ///
    /// # Errors
    ///
    /// Returns an error when PostgreSQL fails other than by refusing the
    /// write.
    pub fn write(
        &mut self,
        principal: &Principal,
        statements: &[String],
    ) -> Result<Verdict, HarnessError> {
        self.act(principal)
            .context(|| format!("acting as {principal}"))?;
        let outcome = statements
            .iter()
            .map(String::as_str)
            .chain(std::iter::once("COMMIT"))
            .try_for_each(|statement| self.connection.batch_execute(statement));
        match outcome {
            Ok(()) => Ok(Verdict::Accepted),
            Err(DieselError::DatabaseError(_, information)) => {
                let verdict = Verdict::Refused {
                    sqlstate: information
                        .sqlstate()
                        .map_or_else(|| "unknown".to_owned(), |code| code.to_string()),
                    message: information.message().to_owned(),
                };
                self.connection
                    .batch_execute("ROLLBACK")
                    .context(|| "rolling back a client write".into())?;
                Ok(verdict)
            }
            Err(source) => Err(HarnessError::Database {
                context: "running a client write on PostgreSQL".into(),
                source,
            }),
        }
    }

    /// Runs `query` as `principal` and answers its single text column per
    /// row.
    fn read_as(&mut self, principal: &Principal, query: &str) -> Result<Vec<String>, HarnessError> {
        self.act(principal)
            .context(|| format!("acting as {principal}"))?;
        let lines = diesel::sql_query(query).load::<Line>(&mut self.connection);
        self.connection
            .batch_execute("ROLLBACK")
            .context(|| "ending a read".into())?;
        Ok(lines
            .context(|| format!("reading as {principal}: {query}"))?
            .into_iter()
            .map(|line| line.line)
            .collect())
    }

    /// The rows `principal` reads from the table of `shape`, over `columns`,
    /// as [`crate::Replica::rows`] reads the replica's view.
    ///
    /// # Errors
    ///
    /// Returns an error when PostgreSQL cannot read the table.
    pub fn rows(
        &mut self,
        principal: &Principal,
        shape: &TableShape,
        columns: &[String],
    ) -> Result<ViewRows, HarnessError> {
        let mut rows = Vec::new();
        if self.readable.contains(&shape.logical) {
            let selected: Vec<String> = columns
                .iter()
                .map(|column| {
                    let column_name = quote(column);
                    match shape.kind(column) {
                        ColumnKind::Timestamp => format!(
                            "CASE WHEN isfinite({column_name}) THEN extract(epoch FROM {column_name})::text \
                             ELSE {column_name}::text END"
                        ),
                        ColumnKind::Bytes => format!("encode({column_name}, 'hex')"),
                        ColumnKind::Jsonb => format!("{column_name}::text"),
                        ColumnKind::Other => column_name,
                    }
                })
                .collect();
            // The table and its columns come from the translation at run
            // time, so no `table!` names them.
            let query = format!(
                "SELECT json_build_array({})::text AS line FROM {}",
                selected.join(", "),
                quote(&shape.logical)
            );
            for line in self.read_as(principal, &query)? {
                rows.push(cells(&shape.logical, &line)?);
            }
        }
        rows.sort();
        Ok(ViewRows {
            table: shape.logical.clone(),
            columns: columns.to_vec(),
            rows,
        })
    }

    /// The rows of the table of `shape` that `principal` reads, as one JSON
    /// array of arrays in the order of the shape's columns, each value as the
    /// replica stores it, or an empty array for a table [`ACTING_ROLE`]
    /// cannot read.
    ///
    /// # Errors
    ///
    /// Returns an error when PostgreSQL cannot read the table.
    pub fn delivery(
        &mut self,
        principal: &Principal,
        shape: &TableShape,
    ) -> Result<String, HarnessError> {
        if !self.readable.contains(&shape.logical) {
            return Ok("[]".to_owned());
        }
        let selected: Vec<String> = shape
            .delivered()
            .map(|(column, kind)| {
                let column_name = quote(column);
                match kind {
                    ColumnKind::Timestamp => format!(
                        "CASE WHEN isfinite({column_name}) THEN to_char({column_name} AT TIME ZONE 'UTC', \
                         'YYYY-MM-DD HH24:MI:SS.MS') || '000+00:00' ELSE {column_name}::text END"
                    ),
                    ColumnKind::Bytes => format!("encode({column_name}, 'hex')"),
                    ColumnKind::Jsonb => format!("{column_name}::text"),
                    ColumnKind::Other => column_name,
                }
            })
            .collect();
        // The table and its columns come from the translation at run time, so
        // no `table!` names them.
        let query = format!(
            "SELECT coalesce(json_agg(json_build_array({})), '[]')::text AS line FROM {}",
            selected.join(", "),
            quote(&shape.logical)
        );
        Ok(self
            .read_as(principal, &query)?
            .into_iter()
            .next()
            .unwrap_or_else(|| "[]".to_owned()))
    }
}
