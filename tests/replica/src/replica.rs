//! One principal's replica, an in-memory SQLite database initialized from the
//! translation.

use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

use diesel::{
    Connection, RunQueryDsl, SqliteConnection,
    connection::SimpleConnection,
    result::{DatabaseErrorKind, Error as DieselError},
    sql_types::{Bool, Nullable, Text},
};
use pg2sqlite::prelude::postgres_error;

use crate::{
    ColumnKind, HarnessError, Principal, TRANSLATION, TableShape, Verdict, ViewRows,
    error::Context,
    jsonb_functions,
    model::{Line, cells, quote},
};

diesel::define_sql_function! {
    /// Answers `app.user_id`.
    fn app_user_id() -> Nullable<Text>;
}
diesel::define_sql_function! {
    /// Answers `app.installation_id`.
    fn app_installation_id() -> Nullable<Text>;
}
diesel::define_sql_function! {
    /// Answers `app.original_actor_id`.
    fn app_original_actor_id() -> Nullable<Text>;
}
diesel::define_sql_function! {
    /// Answers `app.link_ids`.
    fn app_link_ids() -> Nullable<Text>;
}
diesel::define_sql_function! {
    /// Answers `app.verified_email`.
    fn app_verified_email() -> Nullable<Text>;
}
diesel::define_sql_function! {
    /// Answers whether the write running is a delivery from the server.
    fn replica_write_exempt() -> Bool;
}

/// One principal's replica.
pub struct Replica {
    connection: SqliteConnection,
    principal: Principal,
    exempt: Arc<AtomicBool>,
}

impl Replica {
    /// A fresh replica answering the settings of `principal`.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite refuses a statement of the translation.
    pub fn new(principal: &Principal) -> Result<Self, HarnessError> {
        let mut connection =
            SqliteConnection::establish(":memory:").map_err(|source| HarnessError::Connection {
                target: "an in-memory replica".into(),
                source,
            })?;
        jsonb_functions()
            .register(&mut connection)
            .context(|| "registering the jsonb functions".into())?;
        register_settings(&mut connection, principal)
            .context(|| "registering the setting functions".into())?;
        let exempt = Arc::new(AtomicBool::new(false));
        let flag = Arc::clone(&exempt);
        // The flag is set and read on the thread running the statement, so
        // program order alone orders the two.
        replica_write_exempt_utils::register_nondeterministic_impl(&mut connection, move || {
            flag.load(Ordering::Relaxed)
        })
        .context(|| "registering the write exemption".into())?;
        // A replica is a fresh database, so every file runs from scratch.
        for statement in TRANSLATION.script.iter() {
            let text = statement.to_string();
            connection
                .batch_execute(&text)
                .context(|| format!("initializing a replica with {text}"))?;
        }
        Ok(Self {
            connection,
            principal: principal.clone(),
            exempt,
        })
    }

    /// The principal whose settings the replica answers.
    #[must_use]
    pub fn principal(&self) -> &Principal {
        &self.principal
    }

    /// Runs `statements` and the script's checks before commit in one
    /// transaction, as the client writes.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite fails other than by refusing the write.
    pub fn write(&mut self, statements: &[String]) -> Result<Verdict, HarnessError> {
        self.connection
            .batch_execute("BEGIN")
            .context(|| "opening a replica transaction".into())?;
        let before_commit = TRANSLATION
            .script
            .before_commit
            .iter()
            .map(ToString::to_string);
        let outcome = statements
            .iter()
            .cloned()
            .chain(before_commit)
            .chain(std::iter::once("COMMIT".to_owned()))
            .try_for_each(|statement| self.connection.batch_execute(&statement));
        match outcome {
            Ok(()) => Ok(Verdict::Accepted),
            Err(DieselError::DatabaseError(kind, information)) => {
                let message = information.message().to_owned();
                self.rollback()?;
                Ok(Verdict::Refused {
                    sqlstate: sqlstate(kind, &message),
                    message,
                })
            }
            Err(source) => Err(HarnessError::Database {
                context: "running a client write on the replica".into(),
                source,
            }),
        }
    }

    /// Rolls back the transaction a failed write left, which SQLite may
    /// already have rolled back itself.
    fn rollback(&mut self) -> Result<(), HarnessError> {
        match self.connection.batch_execute("ROLLBACK") {
            Err(DieselError::DatabaseError(_, information))
                if information.message().contains("no transaction is active") =>
            {
                Ok(())
            }
            outcome => outcome.context(|| "rolling back a replica transaction".into()),
        }
    }

    /// The rows the view of `shape` shows.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite cannot read the view.
    pub fn rows(&mut self, shape: &TableShape) -> Result<ViewRows, HarnessError> {
        // The pragma's table-valued form takes the view as a bound argument,
        // which the typed DSL has no table for.
        let columns: Vec<String> =
            diesel::sql_query("SELECT name AS line FROM pragma_table_info(?)")
                .bind::<Text, _>(&shape.logical)
                .load::<Line>(&mut self.connection)
                .context(|| format!("reading the columns of {}", shape.logical))?
                .into_iter()
                .map(|line| line.line)
                .collect();
        let selected: Vec<String> = columns
            .iter()
            .map(|column| {
                let column_name = quote(column);
                match shape.kind(column) {
                    ColumnKind::Timestamp => format!(
                        "CASE WHEN {column_name} IN ('infinity', '-infinity') THEN {column_name} \
                         ELSE unixepoch({column_name}, 'subsec') END"
                    ),
                    ColumnKind::Bytes => format!("lower(hex({column_name}))"),
                    ColumnKind::Jsonb | ColumnKind::Other => column_name,
                }
            })
            .collect();
        // The view and its columns come from the translation at run time, so
        // no `table!` names them.
        let query = format!(
            "SELECT json_array({}) AS line FROM {}",
            selected.join(", "),
            quote(&shape.logical)
        );
        let lines: Vec<Line> = diesel::sql_query(query)
            .load(&mut self.connection)
            .context(|| format!("reading the replica's {}", shape.logical))?;
        let mut rows = lines
            .iter()
            .map(|line| cells(&shape.logical, &line.line))
            .collect::<Result<Vec<_>, _>>()?;
        rows.sort();
        Ok(ViewRows {
            table: shape.logical.clone(),
            columns,
            rows,
        })
    }

    /// Replaces every stored row with `delivered`, each table's rows as a JSON
    /// array of arrays in the order of its shape's columns, with the write
    /// guards exempt as a delivery from the server is.
    ///
    /// Answers SQLite's message when it refuses the rows.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite fails other than by refusing the rows.
    pub fn deliver(
        &mut self,
        delivered: &[(&TableShape, String)],
    ) -> Result<Option<String>, HarnessError> {
        self.exempt.store(true, Ordering::Relaxed);
        let outcome = self.replace(delivered);
        self.exempt.store(false, Ordering::Relaxed);
        match outcome {
            Ok(()) => Ok(None),
            Err(DieselError::DatabaseError(_, information)) => {
                let message = information.message().to_owned();
                self.rollback()?;
                Ok(Some(message))
            }
            Err(source) => Err(HarnessError::Database {
                context: "delivering rows to a replica".into(),
                source,
            }),
        }
    }

    /// Deletes every stored row and inserts `delivered` in one transaction.
    fn replace(&mut self, delivered: &[(&TableShape, String)]) -> diesel::QueryResult<()> {
        self.connection
            .batch_execute("BEGIN; PRAGMA defer_foreign_keys = ON")?;
        for (shape, _) in delivered {
            self.connection
                .batch_execute(&format!("DELETE FROM {}", quote(&shape.physical)))?;
        }
        for (shape, rows) in delivered {
            let names: Vec<String> = shape.columns.iter().map(|(name, _)| quote(name)).collect();
            let values: Vec<String> = shape
                .columns
                .iter()
                .enumerate()
                .map(|(index, (_, kind))| {
                    let value = format!("json_extract(value, '$[{index}]')");
                    if *kind == ColumnKind::Bytes {
                        format!("unhex({value})")
                    } else {
                        value
                    }
                })
                .collect();
            // The stored table and its columns come from the translation at
            // run time, so no `table!` names them.
            diesel::sql_query(format!(
                "INSERT INTO {} ({}) SELECT {} FROM json_each(?)",
                quote(&shape.physical),
                names.join(", "),
                values.join(", ")
            ))
            .bind::<Text, _>(rows)
            .execute(&mut self.connection)?;
        }
        self.connection.batch_execute("COMMIT")
    }

    /// What `PRAGMA integrity_check` and `PRAGMA foreign_key_check` report,
    /// each beside its PRAGMA, empty when both pass.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite cannot run a check.
    pub fn integrity(&mut self) -> Result<Vec<(&'static str, Vec<String>)>, HarnessError> {
        let mut failures = Vec::new();
        // PRAGMA results have no `table!`.
        let integrity: Vec<String> =
            diesel::sql_query("SELECT integrity_check AS line FROM pragma_integrity_check")
                .load::<Line>(&mut self.connection)
                .context(|| "running PRAGMA integrity_check".into())?
                .into_iter()
                .map(|line| line.line)
                .filter(|line| line != "ok")
                .collect();
        if !integrity.is_empty() {
            failures.push(("PRAGMA integrity_check", integrity));
        }
        let foreign_keys: Vec<String> = diesel::sql_query(
            "SELECT json_array(\"table\", rowid, parent, fkid) AS line FROM pragma_foreign_key_check",
        )
        .load::<Line>(&mut self.connection)
        .context(|| "running PRAGMA foreign_key_check".into())?
        .into_iter()
        .map(|line| line.line)
        .collect();
        if !foreign_keys.is_empty() {
            failures.push(("PRAGMA foreign_key_check", foreign_keys));
        }
        Ok(failures)
    }
}

/// Registers the function answering each setting of `principal`.
fn register_settings(
    connection: &mut SqliteConnection,
    principal: &Principal,
) -> diesel::QueryResult<()> {
    let value = |setting: &str| Some(principal.value(setting).to_owned());
    let user = value("app.user_id");
    app_user_id_utils::register_nondeterministic_impl(connection, move || user.clone())?;
    let installation = value("app.installation_id");
    app_installation_id_utils::register_nondeterministic_impl(connection, move || {
        installation.clone()
    })?;
    let original = value("app.original_actor_id");
    app_original_actor_id_utils::register_nondeterministic_impl(connection, move || {
        original.clone()
    })?;
    let links = value("app.link_ids");
    app_link_ids_utils::register_nondeterministic_impl(connection, move || links.clone())?;
    let email = value("app.verified_email");
    app_verified_email_utils::register_nondeterministic_impl(connection, move || email.clone())
}

/// The SQLSTATE PostgreSQL reports for the refusal SQLite reported.
fn sqlstate(kind: DatabaseErrorKind, message: &str) -> String {
    if let Some(error) = postgres_error(message) {
        return error.sqlstate().to_string();
    }
    match kind {
        DatabaseErrorKind::UniqueViolation => "23505",
        DatabaseErrorKind::ForeignKeyViolation => "23503",
        DatabaseErrorKind::NotNullViolation => "23502",
        DatabaseErrorKind::CheckViolation => "23514",
        _ => "unmapped",
    }
    .to_owned()
}
