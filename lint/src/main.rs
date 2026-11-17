//! Runs `SQLippy` over the connetto-schema slices and fails on any finding
//! the library configuration does not excuse.

use std::{fs, process::ExitCode};

use connetto_schema_lint::{
    constrainer, deployment, findings, read_slices, root, sqlippy::prelude::ParserDB,
    sqlparser::dialect::PostgreSqlDialect,
};

fn main() -> ExitCode {
    let root = root();
    let bootstrap = fs::read_to_string(root.join("cluster/roles.sql")).expect("cluster bootstrap");
    let slices = read_slices(&root.join("sql")).expect("schema slices");
    let cluster =
        ParserDB::parse::<PostgreSqlDialect>(&bootstrap).expect("cluster bootstrap parses");
    let database = ParserDB::parse::<PostgreSqlDialect>(&format!("{bootstrap}\n{slices}"))
        .expect("schema parses");
    let findings = findings(&constrainer(deployment(&cluster)), &database);
    for finding in &findings {
        println!("{finding}");
    }
    if findings.is_empty() {
        println!("SQLippy reports nothing on the schema");
        ExitCode::SUCCESS
    } else {
        println!("{} SQLippy findings", findings.len());
        ExitCode::FAILURE
    }
}
