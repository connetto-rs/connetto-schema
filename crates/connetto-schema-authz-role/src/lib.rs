//!Auto-generated crate for the PostgreSQL enum type `authz.role`.
/// Diesel SQL types of the crate.
pub mod sql_types {
    ///Diesel SQL type of the `authz.role` PostgreSQL enum type.
    #[derive(
        Debug,
        Clone,
        Copy,
        ::diesel::query_builder::QueryId,
        ::diesel::sql_types::SqlType
    )]
    #[diesel(postgres_type(name = "role", schema = "authz"))]
    #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
    pub struct Role;
}
///Rust enum of the `authz.role` PostgreSQL enum type, ordered as PostgreSQL orders its labels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[derive(::serde::Serialize, ::serde::Deserialize)]
#[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
#[diesel(sql_type = crate::sql_types::Role)]
pub enum Role {
    ///The `reader` label.
    #[serde(rename = "reader")]
    Reader,
    ///The `writer` label.
    #[serde(rename = "writer")]
    Writer,
    ///The `admin` label.
    #[serde(rename = "admin")]
    Admin,
}
impl ::diesel::serialize::ToSql<crate::sql_types::Role, ::diesel::pg::Pg> for Role {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
    ) -> ::diesel::serialize::Result {
        let label: &[u8] = match *self {
            Self::Reader => b"reader",
            Self::Writer => b"writer",
            Self::Admin => b"admin",
        };
        ::std::io::Write::write_all(out, label)?;
        Ok(::diesel::serialize::IsNull::No)
    }
}
impl ::diesel::deserialize::FromSql<crate::sql_types::Role, ::diesel::pg::Pg> for Role {
    fn from_sql(
        value: ::diesel::pg::PgValue<'_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.as_bytes() {
            b"reader" => Ok(Self::Reader),
            b"writer" => Ok(Self::Writer),
            b"admin" => Ok(Self::Admin),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {}", "authz.role",
                        String::from_utf8_lossy(unknown)
                    )
                        .into(),
                )
            }
        }
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::serialize::ToSql<crate::sql_types::Role, ::diesel::sqlite::Sqlite>
for Role {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
    ) -> ::diesel::serialize::Result {
        out.set_value(
            match *self {
                Self::Reader => "reader",
                Self::Writer => "writer",
                Self::Admin => "admin",
            },
        );
        Ok(::diesel::serialize::IsNull::No)
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::deserialize::FromSql<crate::sql_types::Role, ::diesel::sqlite::Sqlite>
for Role {
    fn from_sql(
        mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.read_text() {
            "reader" => Ok(Self::Reader),
            "writer" => Ok(Self::Writer),
            "admin" => Ok(Self::Admin),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {unknown}",
                        "authz.role"
                    )
                        .into(),
                )
            }
        }
    }
}
