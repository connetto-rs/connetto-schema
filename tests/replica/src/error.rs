//! What stops the harness before it can compare the two engines.

use thiserror::Error;

/// A failure of the harness itself, as opposed to a disagreement between the
/// engines, which a scenario reports as a [`crate::Mismatch`].
#[derive(Debug, Error)]
pub enum HarnessError {
    /// `REPLICA_DATABASE_URL` is not set.
    #[error("REPLICA_DATABASE_URL names no PostgreSQL server, run tests/run.sh")]
    MissingDatabaseUrl,
    /// A database refused a statement the harness itself runs.
    #[error("{context}: {source}")]
    Database {
        /// What the harness was doing.
        context: String,
        /// The database's error.
        #[source]
        source: diesel::result::Error,
    },
    /// A connection could not be opened.
    #[error("connecting to {target}: {source}")]
    Connection {
        /// The database the harness connected to.
        target: String,
        /// The connection's error.
        #[source]
        source: diesel::ConnectionError,
    },
    /// pg2sqlite refused to reverse translate a client statement or to
    /// initialize the replica.
    #[error("{context}: {source}")]
    Translation {
        /// What the harness was doing.
        context: String,
        /// pg2sqlite's error, boxed because it outweighs every other variant.
        #[source]
        source: Box<pg2sqlite::prelude::Error>,
    },
    /// A row read back from a database is not the JSON the harness asked for.
    #[error("reading rows of {table}: {source}")]
    Rows {
        /// The table read.
        table: String,
        /// The JSON error.
        #[source]
        source: serde_json::Error,
    },
    /// A scenario file is malformed.
    #[error("{path}:{line}: {reason}")]
    Scenario {
        /// The scenario file.
        path: String,
        /// The line, counted from one.
        line: usize,
        /// What is wrong with it.
        reason: String,
    },
    /// A file could not be read.
    #[error("reading {path}: {source}")]
    Io {
        /// The file.
        path: String,
        /// The I/O error.
        #[source]
        source: std::io::Error,
    },
}

/// Attaches the harness's current activity to a database error.
pub(crate) trait Context<T> {
    /// Wraps the error with `context`.
    fn context(self, context: impl FnOnce() -> String) -> Result<T, HarnessError>;
}

impl<T> Context<T> for Result<T, diesel::result::Error> {
    fn context(self, context: impl FnOnce() -> String) -> Result<T, HarnessError> {
        self.map_err(|source| HarnessError::Database {
            context: context(),
            source,
        })
    }
}
