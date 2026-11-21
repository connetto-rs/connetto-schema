//! Runs `SQLippy` and `rls2fga` over the connetto-schema slices and fails on
//! any finding the library configuration does not excuse and on any clause
//! translating below confidence A.

use std::process::ExitCode;

use connetto_schema_lint::{
    constrainer, deployment,
    rls2fga::parser::sql_parser::parse_schema,
    sqlippy::prelude::{Constrainer, ParserDB},
    sqlparser::dialect::PostgreSqlDialect,
    translation::{self, divergences, registry, translator},
};
use connetto_schema_source::{bootstrap, slices};

fn main() -> ExitCode {
    let bootstrap = bootstrap().expect("cluster bootstrap");
    let schema = bootstrap.clone() + &slices().expect("schema slices");
    let cluster =
        ParserDB::parse::<PostgreSqlDialect>(&bootstrap).expect("cluster bootstrap parses");
    let database = ParserDB::parse::<PostgreSqlDialect>(&schema).expect("schema parses");
    let findings = constrainer(deployment(&cluster)).diagnostics(&database);
    for finding in &findings {
        println!("{finding}");
    }
    let translated = parse_schema(&schema).expect("schema parses for rls2fga");
    let divergences = divergences(
        &translator(translation::deployment(), registry(&translated)),
        &translated,
    )
    .expect("rls2fga plans the model");
    for note in &divergences {
        println!("rls2fga [{}] {}: {note}", note.severity(), note.subject());
    }
    if findings.is_empty() && divergences.is_empty() {
        println!("SQLippy reports nothing and rls2fga translates every clause at A");
        ExitCode::SUCCESS
    } else {
        println!(
            "{} SQLippy findings, {} rls2fga divergences",
            findings.len(),
            divergences.len()
        );
        ExitCode::FAILURE
    }
}
