//!Auto-generated crate for the PostgreSQL enum type `authz.membership_state`.
/// Diesel SQL types of the crate.
pub mod sql_types {
    ///Diesel SQL type of the `authz.membership_state` PostgreSQL enum type.
    #[derive(
        Debug,
        Clone,
        Copy,
        ::diesel::query_builder::QueryId,
        ::diesel::sql_types::SqlType
    )]
    #[diesel(postgres_type(name = "membership_state", schema = "authz"))]
    #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
    pub struct MembershipState;
}
///Rust enum of the `authz.membership_state` PostgreSQL enum type, ordered as PostgreSQL orders its labels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[derive(::serde::Serialize, ::serde::Deserialize)]
#[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
#[diesel(sql_type = crate::sql_types::MembershipState)]
pub enum MembershipState {
    ///The `active` label.
    #[serde(rename = "active")]
    Active,
    ///The `deactivated` label.
    #[serde(rename = "deactivated")]
    Deactivated,
}
impl ::diesel::serialize::ToSql<crate::sql_types::MembershipState, ::diesel::pg::Pg>
for MembershipState {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
    ) -> ::diesel::serialize::Result {
        let label: &[u8] = match *self {
            Self::Active => b"active",
            Self::Deactivated => b"deactivated",
        };
        ::std::io::Write::write_all(out, label)?;
        Ok(::diesel::serialize::IsNull::No)
    }
}
impl ::diesel::deserialize::FromSql<crate::sql_types::MembershipState, ::diesel::pg::Pg>
for MembershipState {
    fn from_sql(
        value: ::diesel::pg::PgValue<'_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.as_bytes() {
            b"active" => Ok(Self::Active),
            b"deactivated" => Ok(Self::Deactivated),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {}",
                        "authz.membership_state", String::from_utf8_lossy(unknown)
                    )
                        .into(),
                )
            }
        }
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::serialize::ToSql<
    crate::sql_types::MembershipState,
    ::diesel::sqlite::Sqlite,
> for MembershipState {
    fn to_sql<'b>(
        &'b self,
        out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
    ) -> ::diesel::serialize::Result {
        out.set_value(
            match *self {
                Self::Active => "active",
                Self::Deactivated => "deactivated",
            },
        );
        Ok(::diesel::serialize::IsNull::No)
    }
}
#[cfg(feature = "sqlite")]
impl ::diesel::deserialize::FromSql<
    crate::sql_types::MembershipState,
    ::diesel::sqlite::Sqlite,
> for MembershipState {
    fn from_sql(
        mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
    ) -> ::diesel::deserialize::Result<Self> {
        match value.read_text() {
            "active" => Ok(Self::Active),
            "deactivated" => Ok(Self::Deactivated),
            unknown => {
                Err(
                    format!(
                        "Unrecognized label of the `{}` enum type: {unknown}",
                        "authz.membership_state"
                    )
                        .into(),
                )
            }
        }
    }
}
