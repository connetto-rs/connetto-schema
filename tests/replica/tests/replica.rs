//! The core schema on its SQLite replica.

use std::{fmt::Write, path::Path};

use connetto_schema_replica::{Principal, Replica, Scenario, TRANSLATION};

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
