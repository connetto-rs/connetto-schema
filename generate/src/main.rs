//! Writes the `connetto-schema` crate of the connetto-schema tables into
//! `crates/`, replacing whatever the directory held.
//!
//! The crate holds every table and enum type, with the models behind its
//! default `models` feature, and the `DESCRIPTION` of the schema SQL that a
//! downstream schema generates its own tables on top of.
//!
//! The crate is committed as synql writes it. CI reruns this binary and
//! fails when `crates/` differs from the commit.

use connetto_schema_source::{root, schema};
use sql_traits::prelude::ParserDB;
use sqlparser::dialect::PostgreSqlDialect;
use synql::prelude::SynQL;

fn main() {
    let schema = schema().expect("schema source");
    let database = ParserDB::parse::<PostgreSqlDialect>(&schema).expect("schema parses");
    let crates = root().join("crates");
    let synql: SynQL<ParserDB> = SynQL::new(&database, &crates)
        .name("connetto-schema")
        .sql(&schema)
        .license("MIT")
        .repository("https://github.com/connetto-rs/connetto-schema")
        .clear_existing()
        .generate_workspace_toml()
        .generate_rustfmt()
        .single_crate()
        .into();
    synql.generate().expect("synql generates the crates");
}
