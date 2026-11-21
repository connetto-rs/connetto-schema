//!Auto-generated crate for the PostgreSQL enum type `authz.resource_kind`.
/// Diesel SQL types of the crate.
pub mod sql_types {
    ///Diesel SQL type of the `authz.resource_kind` PostgreSQL enum type.
    #[derive(
        Debug,
        Clone,
        Copy,
        ::diesel::query_builder::QueryId,
        ::diesel::sql_types::SqlType
    )]
    #[diesel(postgres_type(name = "resource_kind", schema = "authz"))]
    #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
    pub struct ResourceKind;
}
///Rust enum of the `authz.resource_kind` PostgreSQL enum type, ordered as PostgreSQL orders its labels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[derive(::serde::Serialize, ::serde::Deserialize)]
#[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
#[diesel(sql_type = crate::sql_types::ResourceKind)]
pub enum ResourceKind {
    ///The `organization` label.
    #[serde(rename = "organization")]
    Organization,
    ///The `folder` label.
    #[serde(rename = "folder")]
    Folder,
    ///The `project` label.
    #[serde(rename = "project")]
    Project,
    ///The `ownable` label.
    #[serde(rename = "ownable")]
    Ownable,
}
impl ::diesel::serialize::ToSql<crate::sql_types::ResourceKind, ::diesel::pg::Pg>
for ResourceKind {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
    ) -> ::diesel::serialize::Result {
        let label: &[u8] = match *self {
            Self::Organization => b"organization",
            Self::Folder => b"folder",
            Self::Project => b"project",
            Self::Ownable => b"ownable",
        };
        ::std::io::Write::write_all(out, label)?;
        Ok(::diesel::serialize::IsNull::No)
    }
}
impl ::diesel::deserialize::FromSql<crate::sql_types::ResourceKind, ::diesel::pg::Pg>
for ResourceKind {
    fn from_sql(
        value: ::diesel::pg::PgValue<'_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.as_bytes() {
            b"organization" => Ok(Self::Organization),
            b"folder" => Ok(Self::Folder),
            b"project" => Ok(Self::Project),
            b"ownable" => Ok(Self::Ownable),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {}",
                        "authz.resource_kind", String::from_utf8_lossy(unknown)
                    )
                        .into(),
                )
            }
        }
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::serialize::ToSql<crate::sql_types::ResourceKind, ::diesel::sqlite::Sqlite>
for ResourceKind {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
    ) -> ::diesel::serialize::Result {
        out.set_value(
            match *self {
                Self::Organization => "organization",
                Self::Folder => "folder",
                Self::Project => "project",
                Self::Ownable => "ownable",
            },
        );
        Ok(::diesel::serialize::IsNull::No)
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::deserialize::FromSql<
    crate::sql_types::ResourceKind,
    ::diesel::sqlite::Sqlite,
> for ResourceKind {
    fn from_sql(
        mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.read_text() {
            "organization" => Ok(Self::Organization),
            "folder" => Ok(Self::Folder),
            "project" => Ok(Self::Project),
            "ownable" => Ok(Self::Ownable),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {unknown}",
                        "authz.resource_kind"
                    )
                        .into(),
                )
            }
        }
    }
}
