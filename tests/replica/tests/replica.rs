//! The core schema on its SQLite replica.

use std::{fmt::Write, path::Path};

use connetto_schema_lint::{
    IRREVERSIBLE_COLUMNS, RAISED_GROUPS, TENANT_ROOT, TENANT_TABLES,
    sqlippy::prelude::{Constrainer, DefaultConstrainer, Deployment, Level, ParserDB},
};
use connetto_schema_replica::{
    Principal, Replica, SERVER_DERIVED_TABLES, Scenario, TRANSLATION, setting_function,
};
use pg2sqlite::prelude::{Placement, TranslationWarning};
use sql_traits::prelude::{ColumnLike, DatabaseLike, ForeignKeyLike, ParseOptions, TableLike};
use sqlparser::dialect::SQLiteDialect;

/// The warning list the translation is held to.
const WARNINGS: &str = "warnings.txt";

/// The translation loads into SQLite, passes both PRAGMA checks and reports
/// exactly the committed warnings. `UPDATE_EXPECT=1` rewrites the list.
#[test]
fn translation_loads() {
    let mut replica =
        Replica::new(&Principal::new([]).expect("no setting")).expect("replica loads");
    assert_eq!(replica.integrity().expect("checks run"), Vec::new());
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join(WARNINGS);
    let mut actual = String::new();
    for warning in &TRANSLATION.warnings {
        writeln!(actual, "{warning}").expect("writing to a String succeeds");
    }
    if std::env::var_os("UPDATE_EXPECT").is_some() {
        std::fs::write(&path, &actual).expect("warning list written");
    }
    let expected = std::fs::read_to_string(&path).unwrap_or_default();
    assert!(
        expected == actual,
        "the translation's warnings differ from {WARNINGS}, rerun with UPDATE_EXPECT=1 and review the diff\n{actual}"
    );
}

/// Every scenario agrees on both engines.
#[test]
fn scenarios() {
    let scenarios = Scenario::all().expect("scenarios load");
    assert!(
        !scenarios.is_empty(),
        "no scenario under tests/replica/scenarios"
    );
    let mut failures = Vec::new();
    for scenario in &scenarios {
        match scenario.run() {
            Ok(None) => {}
            Ok(Some(failure)) => failures.push(failure.to_string()),
            Err(error) => failures.push(format!("{}: {error}", scenario.path.display())),
        }
    }
    assert!(
        failures.is_empty(),
        "{} of {} scenarios fail\n\n{}",
        failures.len(),
        scenarios.len(),
        failures.join("\n\n")
    );
}

/// The table holding the rows of the source table `logical` on the replica.
fn physical(logical: &str) -> &'static str {
    let entry = TRANSLATION
        .manifest
        .iter()
        .find(|entry| entry.logical == logical)
        .unwrap_or_else(|| panic!("the replica does not hold {logical}"));
    assert_eq!(entry.physical_placement, Placement::Main);
    &entry.physical
}

/// The deployment the replica serves, as its SQLite schema names it.
fn replica_deployment() -> Deployment {
    let caller = format!(
        "unhex(replace(replace(replace(NULLIF({}(), ''), '-', ''), '{{', ''), '}}', ''))",
        setting_function("app.user_id")
    );
    let mut deployment = Deployment::default()
        .without_anonymous_roles()
        .without_app_roles()
        .without_binary_replication_tables()
        .without_self_asserted_sources()
        // The server alone writes the audit trail, so the replica omits it.
        .without_audit_functions()
        .with_credential(&caller)
        .expect("caller parses")
        .with_credential(&format!("{}()", setting_function("app.verified_email")))
        .expect("verified email parses")
        .with_request_setting(&format!("{}()", setting_function("app.installation_id")))
        .expect("installation parses")
        .with_tenant_key("main", physical(TENANT_ROOT), "id");
    for table in TENANT_TABLES {
        deployment = deployment.with_tenant_key("main", physical(table), "organization_id");
    }
    for (table, column) in IRREVERSIBLE_COLUMNS {
        deployment = deployment.with_irreversible_column("main", physical(table), *column);
    }
    for entry in &TRANSLATION.manifest {
        // Connetto applies the server's changesets to every replica table.
        deployment = deployment.with_subscribed_table("main", physical(&entry.logical));
        if !SERVER_DERIVED_TABLES.contains(&entry.logical.as_str()) {
            deployment = deployment.with_client_written_table("main", physical(&entry.logical));
        }
    }
    let schema = &TRANSLATION.schema;
    for warning in &TRANSLATION.warnings {
        let TranslationWarning::HiddenReferencedRows { name, table, .. } = warning else {
            continue;
        };
        let host = schema
            .table_by_stored_identity(None, table)
            .unwrap_or_else(|| panic!("source table {table} for foreign key {name} is missing"));
        let foreign_key = host
            .foreign_keys(schema)
            .expect("source foreign keys resolve")
            .find(|foreign_key| {
                foreign_key
                    .constraint_name(schema)
                    .expect("source foreign key name resolves")
                    .as_deref()
                    == Some(name.as_str())
            })
            .unwrap_or_else(|| panic!("source foreign key {name} on {table} is missing"));
        let referenced = foreign_key
            .referenced_table(schema)
            .expect("referenced source table resolves");
        deployment = deployment.with_external_foreign_key(
            "main",
            physical(table),
            foreign_key
                .host_columns(schema)
                .expect("host columns resolve")
                .map(ColumnLike::column_name),
            "main",
            physical(referenced.table_name()),
            foreign_key
                .referenced_columns(schema)
                .expect("referenced columns resolve")
                .map(ColumnLike::column_name),
        );
    }
    deployment
}

/// `SQLippy` reports nothing on the SQLite schema the replica runs.
#[test]
fn sqlippy_reports_nothing() {
    let mut script = String::new();
    for statement in TRANSLATION.script.iter() {
        writeln!(script, "{statement};").expect("writing to a String succeeds");
    }
    let database = ParseOptions::default()
        .parse::<SQLiteDialect>(&script)
        .expect("the replica parses as SQLite");
    let mut constrainer = DefaultConstrainer::<ParserDB>::default();
    constrainer.set_deployment(replica_deployment());
    for group in RAISED_GROUPS {
        constrainer.set_group_level(group, Level::Warn);
    }
    let findings: Vec<String> = constrainer
        .diagnostics(&database)
        .iter()
        .map(ToString::to_string)
        .collect();
    assert!(
        findings.is_empty(),
        "{} SQLippy findings on the replica\n{}",
        findings.len(),
        findings.join("\n")
    );
}
