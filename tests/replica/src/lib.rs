//! Runs the connetto-schema core on the SQLite replica pg2sqlite translates it
//! into, beside PostgreSQL.
//!
//! [`TRANSLATION`] translates `cluster/roles.sql` and every slice under `sql/`
//! with the options the replica runs under. A scenario under
//! `tests/replica/scenarios` then drives a PostgreSQL database cloned from the
//! template `tests/run.sh` builds and one replica per acting principal through
//! the same steps. A client step runs on its principal's replica and, reverse
//! translated, as `app` on PostgreSQL, and both engines have to give the
//! verdict the step expects and show the principal the same rows. A write
//! only the server can refuse, because it rests on rows the principal never
//! receives, has to be accepted by the replica and refused by PostgreSQL.
//! After every step the server commits, each replica receives the rows its
//! principal reads on PostgreSQL, the way connetto delivers them, which also
//! reverts a write the server refused.

mod error;
mod model;
mod replica;
mod scenario;
mod server;

use std::sync::LazyLock;

pub use error::HarnessError;
pub use model::{
    CLOCK_SKEW_SECONDS, Cell, ColumnKind, Mismatch, Moment, Principal, TableShape, Verdict,
    ViewRows,
};
use pg2sqlite::prelude::{
    ArrayRepresentation, CaseFoldFunctions, JsonbFunctions, Pg2Sqlite, Pg2SqliteOptions, Script,
    SessionVariableMapping, TableManifestEntry, TranslationWarning, UuidRepresentation,
};
pub use replica::Replica;
pub use scenario::{Failure, Outcome, Scenario, Step};
pub use server::Server;
use sql_traits::structs::{Deployment, ParserDB, SessionSetting, SetPacking, SettingValue};
use sqlparser::ast::DataType;

/// The session settings a request carries, each beside the key a scenario
/// names it by.
pub const SETTINGS: [(&str, &str); 5] = [
    ("user", "app.user_id"),
    ("installation", "app.installation_id"),
    ("original", "app.original_actor_id"),
    ("links", "app.link_ids"),
    ("email", "app.verified_email"),
];

/// The role every request runs as.
pub const ACTING_ROLE: &str = "app";

/// The function a replica registers to lift row-level security, reads and
/// writes alike, from the rows the server delivers, as for the table owner.
pub const RLS_EXEMPTION_FUNCTION: &str = "replica_rls_exempt";

/// The tables only the server writes, whose rows a replica receives and never
/// derives from its own writes.
pub const SERVER_DERIVED_TABLES: &[&str] = &["audit_events", "grantees", "platform_audit_events"];

/// The SQLite function that answers `setting` on the replica.
#[must_use]
pub fn setting_function(setting: &str) -> String {
    setting.replace('.', "_")
}

/// The functions and collation the replica's `jsonb` columns use.
#[must_use]
pub fn jsonb_functions() -> JsonbFunctions {
    JsonbFunctions::new("pg_jsonb", "pg_jsonb_text", "pg_jsonb")
}

/// The functions the replica's `lower` and `upper` call, folding as the
/// server's glibc `en_US.utf8` collation does.
#[must_use]
pub fn case_fold_functions() -> CaseFoldFunctions {
    CaseFoldFunctions::new("pg_lower", "pg_upper")
}

/// The deployment the replica serves, declaring what each of [`SETTINGS`]
/// holds.
///
/// # Panics
///
/// Panics if sql-traits refuses one of the settings.
#[must_use]
pub fn deployment() -> Deployment {
    let unset = |name: &str, value| {
        SessionSetting::value(name, value)
            .expect("session setting")
            .may_be_unset()
    };
    Deployment::new(
        ACTING_ROLE,
        [ACTING_ROLE],
        [
            unset("app.user_id", SettingValue::Caller(DataType::Uuid)),
            unset(
                "app.installation_id",
                SettingValue::Principal {
                    kind: "installation".into(),
                    identity: DataType::Uuid,
                },
            ),
            unset(
                "app.original_actor_id",
                SettingValue::Scalar(DataType::Uuid),
            ),
            unset(
                "app.link_ids",
                SettingValue::Set {
                    element: DataType::Uuid,
                    packing: SetPacking::Delimited(",".into()),
                },
            ),
            unset("app.verified_email", SettingValue::Scalar(DataType::Text)),
        ],
    )
    .expect("deployment")
}

/// The options a client's statement reverse translates under, which name no
/// acting role because the server runs the statement as [`ACTING_ROLE`].
#[must_use]
pub fn query_options() -> Pg2SqliteOptions {
    let mut options = Pg2SqliteOptions::default()
        .with_uuid_representation(UuidRepresentation::Blob)
        .with_array_representation(ArrayRepresentation::Json)
        .with_rls_audit_table_name("rls_violations")
        .with_rls_exemption_function(RLS_EXEMPTION_FUNCTION)
        .with_jsonb_functions(jsonb_functions())
        .with_case_fold_functions(case_fold_functions())
        .with_server_derived_write_function("replica_server_derived_write")
        .with_deployment(deployment());
    for (_, setting) in SETTINGS {
        options = options.with_session_variable(SessionVariableMapping::new(
            setting,
            setting_function(setting),
        ));
    }
    options
}

/// A translation of [`connetto_schema_source::schema`] and what the harness
/// reads off it.
pub struct Translation {
    /// The parsed source, which also reverse translates.
    pub translator: Pg2Sqlite,
    /// The PostgreSQL schema reverse translation resolves names against.
    pub schema: ParserDB,
    /// The options the replica translates under.
    pub replica_options: Pg2SqliteOptions,
    /// The options a client's statement reverse translates under.
    pub query_options: Pg2SqliteOptions,
    /// The replica's statements.
    pub script: Script,
    /// Every warning, as the translation reports it.
    pub warnings: Vec<TranslationWarning>,
    /// Each table the replica holds, with the view a client reads it through.
    pub manifest: Vec<TableManifestEntry>,
}

/// The translation every test shares, made on first use.
///
/// # Panics
///
/// Panics if pg2sqlite refuses the source.
pub static TRANSLATION: LazyLock<Translation> = LazyLock::new(|| {
    let translator = Pg2Sqlite::default()
        .sql(&connetto_schema_source::schema().expect("schema source"))
        .expect("source parses");
    let query_options = query_options();
    let replica_options = query_options.clone().with_acting_role(ACTING_ROLE);
    let report = translator
        .translate_with_report(&replica_options)
        .expect("source translates");
    let manifest = translator
        .translation_manifest(&replica_options)
        .expect("manifest");
    let schema = translator.build_schema().expect("schema");
    Translation {
        translator,
        schema,
        replica_options,
        query_options,
        warnings: report.warnings,
        script: report.script,
        manifest,
    }
});
