//! Writes the synql crates of the connetto-schema tables into `crates/`,
//! replacing whatever the directory held.
//!
//! The `connetto-schema-synql` crate among them records the schema SQL and
//! the crate holding each table, so a downstream schema generates only its
//! own tables on top of these crates.
//!
//! The crates are committed as synql writes them. CI reruns this binary and
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
        .sink_crate("connetto-schema")
        .into();
    synql.generate().expect("synql generates the crates");
}
