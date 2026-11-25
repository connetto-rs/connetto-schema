#![allow(
    ambiguous_glob_reexports,
    reason = "TableModel trait names can collide across tables"
)]
extern crate self as connetto_schema;
/// The description of the workspace, which `synql` parses as a
/// `BaseWorkspace` to generate another schema on top of it.
pub const DESCRIPTION: &str = include_str!("../synql.toml");
#[cfg(feature = "models")]
pub mod authz_audit_operation {
    pub mod sql_types {
        #[derive(
            Debug,
            Clone,
            Copy,
            ::diesel::query_builder::QueryId,
            ::diesel::sql_types::SqlType
        )]
        #[diesel(postgres_type(name = "audit_operation", schema = "authz"))]
        #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
        pub struct AuditOperation;
    }
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::AuditOperation)]
    pub enum AuditOperation {
        #[serde(rename = "INSERT")]
        Insert,
        #[serde(rename = "UPDATE")]
        Update,
        #[serde(rename = "DELETE")]
        Delete,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::AuditOperation, ::diesel::pg::Pg>
    for AuditOperation {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
        ) -> ::diesel::serialize::Result {
            let label: &[u8] = match *self {
                Self::Insert => b"INSERT",
                Self::Update => b"UPDATE",
                Self::Delete => b"DELETE",
            };
            ::std::io::Write::write_all(out, label)?;
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    impl ::diesel::deserialize::FromSql<
        self::sql_types::AuditOperation,
        ::diesel::pg::Pg,
    > for AuditOperation {
        fn from_sql(
            value: ::diesel::pg::PgValue<'_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.as_bytes() {
                b"INSERT" => Ok(Self::Insert),
                b"UPDATE" => Ok(Self::Update),
                b"DELETE" => Ok(Self::Delete),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {}",
                            "authz.audit_operation", String::from_utf8_lossy(unknown)
                        )
                            .into(),
                    )
                }
            }
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::serialize::ToSql<
        self::sql_types::AuditOperation,
        ::diesel::sqlite::Sqlite,
    > for AuditOperation {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
        ) -> ::diesel::serialize::Result {
            out.set_value(
                match *self {
                    Self::Insert => "INSERT",
                    Self::Update => "UPDATE",
                    Self::Delete => "DELETE",
                },
            );
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::deserialize::FromSql<
        self::sql_types::AuditOperation,
        ::diesel::sqlite::Sqlite,
    > for AuditOperation {
        fn from_sql(
            mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.read_text() {
                "INSERT" => Ok(Self::Insert),
                "UPDATE" => Ok(Self::Update),
                "DELETE" => Ok(Self::Delete),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {unknown}",
                            "authz.audit_operation"
                        )
                            .into(),
                    )
                }
            }
        }
    }
}
#[cfg(feature = "models")]
pub mod authz_grantee_kind {
    pub mod sql_types {
        #[derive(
            Debug,
            Clone,
            Copy,
            ::diesel::query_builder::QueryId,
            ::diesel::sql_types::SqlType
        )]
        #[diesel(postgres_type(name = "grantee_kind", schema = "authz"))]
        #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
        pub struct GranteeKind;
    }
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::GranteeKind)]
    pub enum GranteeKind {
        #[serde(rename = "user")]
        User,
        #[serde(rename = "installation")]
        Installation,
        #[serde(rename = "team")]
        Team,
        #[serde(rename = "organization")]
        Organization,
        #[serde(rename = "everyone")]
        Everyone,
        #[serde(rename = "signed_in")]
        SignedIn,
        #[serde(rename = "link")]
        Link,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::GranteeKind, ::diesel::pg::Pg>
    for GranteeKind {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
        ) -> ::diesel::serialize::Result {
            let label: &[u8] = match *self {
                Self::User => b"user",
                Self::Installation => b"installation",
                Self::Team => b"team",
                Self::Organization => b"organization",
                Self::Everyone => b"everyone",
                Self::SignedIn => b"signed_in",
                Self::Link => b"link",
            };
            ::std::io::Write::write_all(out, label)?;
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    impl ::diesel::deserialize::FromSql<self::sql_types::GranteeKind, ::diesel::pg::Pg>
    for GranteeKind {
        fn from_sql(
            value: ::diesel::pg::PgValue<'_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.as_bytes() {
                b"user" => Ok(Self::User),
                b"installation" => Ok(Self::Installation),
                b"team" => Ok(Self::Team),
                b"organization" => Ok(Self::Organization),
                b"everyone" => Ok(Self::Everyone),
                b"signed_in" => Ok(Self::SignedIn),
                b"link" => Ok(Self::Link),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {}",
                            "authz.grantee_kind", String::from_utf8_lossy(unknown)
                        )
                            .into(),
                    )
                }
            }
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::serialize::ToSql<
        self::sql_types::GranteeKind,
        ::diesel::sqlite::Sqlite,
    > for GranteeKind {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
        ) -> ::diesel::serialize::Result {
            out.set_value(
                match *self {
                    Self::User => "user",
                    Self::Installation => "installation",
                    Self::Team => "team",
                    Self::Organization => "organization",
                    Self::Everyone => "everyone",
                    Self::SignedIn => "signed_in",
                    Self::Link => "link",
                },
            );
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::deserialize::FromSql<
        self::sql_types::GranteeKind,
        ::diesel::sqlite::Sqlite,
    > for GranteeKind {
        fn from_sql(
            mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.read_text() {
                "user" => Ok(Self::User),
                "installation" => Ok(Self::Installation),
                "team" => Ok(Self::Team),
                "organization" => Ok(Self::Organization),
                "everyone" => Ok(Self::Everyone),
                "signed_in" => Ok(Self::SignedIn),
                "link" => Ok(Self::Link),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {unknown}",
                            "authz.grantee_kind"
                        )
                            .into(),
                    )
                }
            }
        }
    }
}
#[cfg(feature = "models")]
pub mod authz_membership_state {
    pub mod sql_types {
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
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::MembershipState)]
    pub enum MembershipState {
        #[serde(rename = "active")]
        Active,
        #[serde(rename = "deactivated")]
        Deactivated,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::MembershipState, ::diesel::pg::Pg>
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
    impl ::diesel::deserialize::FromSql<
        self::sql_types::MembershipState,
        ::diesel::pg::Pg,
    > for MembershipState {
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
        self::sql_types::MembershipState,
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
        self::sql_types::MembershipState,
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
}
#[cfg(feature = "models")]
pub mod authz_resource_kind {
    pub mod sql_types {
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
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::ResourceKind)]
    pub enum ResourceKind {
        #[serde(rename = "organization")]
        Organization,
        #[serde(rename = "folder")]
        Folder,
        #[serde(rename = "project")]
        Project,
        #[serde(rename = "ownable")]
        Ownable,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::ResourceKind, ::diesel::pg::Pg>
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
    impl ::diesel::deserialize::FromSql<self::sql_types::ResourceKind, ::diesel::pg::Pg>
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
    impl ::diesel::serialize::ToSql<
        self::sql_types::ResourceKind,
        ::diesel::sqlite::Sqlite,
    > for ResourceKind {
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
        self::sql_types::ResourceKind,
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
}
#[cfg(feature = "models")]
pub mod authz_role {
    pub mod sql_types {
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
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::Role)]
    pub enum Role {
        #[serde(rename = "reader")]
        Reader,
        #[serde(rename = "writer")]
        Writer,
        #[serde(rename = "admin")]
        Admin,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::Role, ::diesel::pg::Pg> for Role {
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
    impl ::diesel::deserialize::FromSql<self::sql_types::Role, ::diesel::pg::Pg>
    for Role {
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
    impl ::diesel::serialize::ToSql<self::sql_types::Role, ::diesel::sqlite::Sqlite>
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
    impl ::diesel::deserialize::FromSql<self::sql_types::Role, ::diesel::sqlite::Sqlite>
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
}
#[cfg(feature = "models")]
pub mod authz_team_role {
    pub mod sql_types {
        #[derive(
            Debug,
            Clone,
            Copy,
            ::diesel::query_builder::QueryId,
            ::diesel::sql_types::SqlType
        )]
        #[diesel(postgres_type(name = "team_role", schema = "authz"))]
        #[cfg_attr(feature = "sqlite", diesel(sqlite_type(name = "Text")))]
        pub struct TeamRole;
    }
    #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(::diesel::AsExpression, ::diesel::FromSqlRow)]
    #[diesel(sql_type = self::sql_types::TeamRole)]
    pub enum TeamRole {
        #[serde(rename = "member")]
        Member,
        #[serde(rename = "admin")]
        Admin,
    }
    impl ::diesel::serialize::ToSql<self::sql_types::TeamRole, ::diesel::pg::Pg>
    for TeamRole {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::pg::Pg>,
        ) -> ::diesel::serialize::Result {
            let label: &[u8] = match *self {
                Self::Member => b"member",
                Self::Admin => b"admin",
            };
            ::std::io::Write::write_all(out, label)?;
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    impl ::diesel::deserialize::FromSql<self::sql_types::TeamRole, ::diesel::pg::Pg>
    for TeamRole {
        fn from_sql(
            value: ::diesel::pg::PgValue<'_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.as_bytes() {
                b"member" => Ok(Self::Member),
                b"admin" => Ok(Self::Admin),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {}",
                            "authz.team_role", String::from_utf8_lossy(unknown)
                        )
                            .into(),
                    )
                }
            }
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::serialize::ToSql<self::sql_types::TeamRole, ::diesel::sqlite::Sqlite>
    for TeamRole {
        fn to_sql<'b>(
            &'b self,
            out: &mut ::diesel::serialize::Output<'b, '_, ::diesel::sqlite::Sqlite>,
        ) -> ::diesel::serialize::Result {
            out.set_value(
                match *self {
                    Self::Member => "member",
                    Self::Admin => "admin",
                },
            );
            Ok(::diesel::serialize::IsNull::No)
        }
    }
    #[cfg(feature = "sqlite")]
    impl ::diesel::deserialize::FromSql<
        self::sql_types::TeamRole,
        ::diesel::sqlite::Sqlite,
    > for TeamRole {
        fn from_sql(
            mut value: ::diesel::sqlite::SqliteValue<'_, '_, '_>,
        ) -> ::diesel::deserialize::Result<Self> {
            match value.read_text() {
                "member" => Ok(Self::Member),
                "admin" => Ok(Self::Admin),
                unknown => {
                    Err(
                        format!(
                            "Unrecognized label of the `{}` enum type: {unknown}",
                            "authz.team_role"
                        )
                            .into(),
                    )
                }
            }
        }
    }
}
#[cfg(feature = "models")]
pub mod app_installations_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(belongs_to(connetto_schema::App, foreign_key = app_id))]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[table_model(foreign_key((app_id), (::connetto_schema::apps::id)))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(
        foreign_key(
            (id, kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = app_installations)]
    pub struct AppInstallation {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        app_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(
        app_installations::organization_id, app_installations::id
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema::apps
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema::organizations
    );
}
#[cfg(feature = "models")]
pub use app_installations_model::*;
#[cfg(feature = "models")]
pub mod apps_model {
    #[derive(Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[diesel(table_name = apps)]
    pub struct App {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        name: String,
    }
    impl ::diesel_builders::ValidateColumn<apps::name>
    for <apps::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(name: &String) -> Result<(), Self::Error> {
            use diesel::Column;
            if name.is_empty() {
                return Err(
                    ::validation_errors::ValidationError::empty(
                        <crate::apps::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::apps::name::NAME,
                    ),
                );
            }
            if name.chars().count() > 200usize {
                return Err(
                    ::validation_errors::ValidationError::exceeds_max_length(
                        <crate::apps::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::apps::name::NAME,
                        200usize,
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        apps, ::connetto_schema::organizations
    );
}
#[cfg(feature = "models")]
pub use apps_model::*;
#[cfg(feature = "models")]
pub mod audit_events_model {
    #[derive(Clone, Debug, Hash, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///No foreign keys, so the record outlives the rows, principals and organizations it names.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(surrogate_key)]
    #[diesel(table_name = audit_events)]
    pub struct AuditEvent {
        id: i64,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        at: ::rosetta_utc::TimestampUTC,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        actor_id: Option<::rosetta_uuid::Uuid>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        original_actor_id: Option<::rosetta_uuid::Uuid>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        installation_id: Option<::rosetta_uuid::Uuid>,
        table_name: String,
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema::authz_audit_operation::sql_types::AuditOperation
        )]
        operation: ::connetto_schema::authz_audit_operation::AuditOperation,
        #[infallible]
        #[diesel(sql_type = ::diesel::sql_types::Jsonb)]
        old_row: Option<::serde_json::Value>,
        #[infallible]
        #[diesel(sql_type = ::diesel::sql_types::Jsonb)]
        new_row: Option<::serde_json::Value>,
    }
    impl ::diesel_builders::ValidateColumn<audit_events::table_name>
    for <audit_events::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(table_name: &String) -> Result<(), Self::Error> {
            use diesel::Column;
            if table_name.is_empty() {
                return Err(
                    ::validation_errors::ValidationError::empty(
                        <crate::audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::audit_events::table_name::NAME,
                    ),
                );
            }
            if table_name.chars().count() > 63usize {
                return Err(
                    ::validation_errors::ValidationError::exceeds_max_length(
                        <crate::audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::audit_events::table_name::NAME,
                        63usize,
                    ),
                );
            }
            Ok(())
        }
    }
    impl ::diesel_builders::ValidateRecord<audit_events::table>
    for <audit_events::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(operation), Some(old_row), Some(new_row)) = (
                <Self as diesel_builders::MayGetColumn<
                    audit_events::operation,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    audit_events::old_row,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    audit_events::new_row,
                >>::may_get_column_ref(self),
            ) {
                if (*operation
                    == ::connetto_schema::authz_audit_operation::AuditOperation::Insert)
                    != old_row.as_ref().is_none()
                {
                    return Err(
                        ::validation_errors::ValidationError::check_violated(
                            <crate::audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                            &[
                                crate::audit_events::operation::NAME,
                                crate::audit_events::old_row::NAME,
                            ],
                            "(operation = 'INSERT') = (old_row IS NULL)",
                        ),
                    );
                }
                if (*operation
                    == ::connetto_schema::authz_audit_operation::AuditOperation::Delete)
                    != new_row.as_ref().is_none()
                {
                    return Err(
                        ::validation_errors::ValidationError::check_violated(
                            <crate::audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                            &[
                                crate::audit_events::operation::NAME,
                                crate::audit_events::new_row::NAME,
                            ],
                            "(operation = 'DELETE') = (new_row IS NULL)",
                        ),
                    );
                }
            }
            Ok(())
        }
    }
}
#[cfg(feature = "models")]
pub use audit_events_model::*;
#[cfg(feature = "models")]
pub mod grantees_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(table_name = grantees)]
    pub struct Grantee {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
    }
    ::diesel_builders::prelude::unique_index!(grantees::id, grantees::kind);
}
#[cfg(feature = "models")]
pub use grantees_model::*;
#[cfg(feature = "models")]
pub mod grants_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[diesel(primary_key(resource_id, grantee_id))]
    #[table_model(
        foreign_key(
            (organization_id, resource_id),
            (
                ::connetto_schema::resources::organization_id,
                ::connetto_schema::resources::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (grantee_id, grantee_kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = grants)]
    pub struct Grant {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        resource_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        grantee_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        grantee_kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[infallible]
        #[diesel(sql_type = ::connetto_schema::authz_role::sql_types::Role)]
        role: ::connetto_schema::authz_role::Role,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: Option<::rosetta_utc::TimestampUTC>,
    }
    impl ::diesel_builders::ValidateRecord<grants::table>
    for <grants::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(grantee_kind), Some(role)) = (
                <Self as diesel_builders::MayGetColumn<
                    grants::grantee_kind,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    grants::role,
                >>::may_get_column_ref(self),
            )
                && !((((*grantee_kind
                    != ::connetto_schema::authz_grantee_kind::GranteeKind::Everyone)
                    && (*grantee_kind
                        != ::connetto_schema::authz_grantee_kind::GranteeKind::SignedIn))
                    && (*grantee_kind
                        != ::connetto_schema::authz_grantee_kind::GranteeKind::Link))
                    || (*role < ::connetto_schema::authz_role::Role::Admin))
            {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::grants::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::grants::grantee_kind::NAME, crate::grants::role::NAME],
                        "grantee_kind NOT IN ('everyone', 'signed_in', 'link') OR role < 'admin'",
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(grants, ::connetto_schema::grantees);
    ::diesel::allow_tables_to_appear_in_same_query!(
        grants, ::connetto_schema::resources
    );
}
#[cfg(feature = "models")]
pub use grants_model::*;
#[cfg(feature = "models")]
pub mod installation_permissions_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(primary_key(installation_id, kind))]
    #[table_model(
        foreign_key(
            (organization_id, installation_id),
            (
                ::connetto_schema::app_installations::organization_id,
                ::connetto_schema::app_installations::id
            )
        )
    )]
    #[diesel(table_name = installation_permissions)]
    pub struct InstallationPermission {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        installation_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema::authz_resource_kind::ResourceKind,
        #[diesel(sql_type = ::connetto_schema::authz_role::sql_types::Role)]
        max_role: ::connetto_schema::authz_role::Role,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        installation_permissions, ::connetto_schema::app_installations
    );
}
#[cfg(feature = "models")]
pub use installation_permissions_model::*;
#[cfg(feature = "models")]
pub mod invitations_model {
    #[derive(Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(foreign_key((invited_by_id), (::connetto_schema::users::id)))]
    #[table_model(foreign_key((accepted_by_id), (::connetto_schema::users::id)))]
    #[diesel(table_name = invitations)]
    pub struct Invitation {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        email: String,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: ::rosetta_utc::TimestampUTC,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        invited_by_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        accepted_by_id: Option<::rosetta_uuid::Uuid>,
    }
    ::diesel_builders::prelude::unique_index!(
        invitations::organization_id, invitations::id
    );
    impl ::diesel_builders::ValidateColumn<invitations::email>
    for <invitations::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(email: &String) -> Result<(), Self::Error> {
            use diesel::Column;
            if email.is_empty() {
                return Err(
                    ::validation_errors::ValidationError::empty(
                        <crate::invitations::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::invitations::email::NAME,
                    ),
                );
            }
            if email.chars().count() > 320usize {
                return Err(
                    ::validation_errors::ValidationError::exceeds_max_length(
                        <crate::invitations::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::invitations::email::NAME,
                        320usize,
                    ),
                );
            }
            if !({
                let text = email.as_str();
                'like: {
                    let mut rest = text.chars();
                    loop {
                        let mut candidate = rest.clone();
                        if candidate.next().is_some() && candidate.next() == Some('@')
                            && candidate.next().is_some()
                        {
                            break 'like true;
                        }
                        if rest.next().is_none() {
                            break 'like false;
                        }
                    }
                }
            }) {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::invitations::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::invitations::email::NAME],
                        "email LIKE '%_@_%'",
                    ),
                );
            }
            if email.as_str() != email.as_str().to_lowercase().as_str() {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::invitations::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::invitations::email::NAME],
                        "email = lower(email)",
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        invitations, ::connetto_schema::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        invitations, ::connetto_schema::users
    );
}
#[cfg(feature = "models")]
pub use invitations_model::*;
#[cfg(feature = "models")]
pub mod memberships_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[diesel(belongs_to(connetto_schema::User, foreign_key = user_id))]
    #[diesel(primary_key(organization_id, user_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(foreign_key((user_id), (::connetto_schema::users::id)))]
    #[table_model(
        foreign_key(
            (organization_id, invitation_id),
            (
                ::connetto_schema::invitations::organization_id,
                ::connetto_schema::invitations::id
            )
        )
    )]
    #[diesel(table_name = memberships)]
    pub struct Membership {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        user_id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_membership_state::sql_types::MembershipState
        )]
        state: ::connetto_schema::authz_membership_state::MembershipState,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        invitation_id: Option<::rosetta_uuid::Uuid>,
    }
    ::diesel_builders::prelude::unique_index!(memberships::invitation_id);
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema::invitations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema::users
    );
}
#[cfg(feature = "models")]
pub use memberships_model::*;
#[cfg(feature = "models")]
pub mod organization_blocks_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[diesel(primary_key(organization_id, principal_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(
        foreign_key(
            (principal_id, principal_kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = organization_blocks)]
    pub struct OrganizationBlock {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        principal_id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        principal_kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: Option<::rosetta_utc::TimestampUTC>,
    }
    impl ::diesel_builders::ValidateColumn<organization_blocks::principal_kind>
    for <organization_blocks::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(
            principal_kind: &::connetto_schema::authz_grantee_kind::GranteeKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*principal_kind
                == ::connetto_schema::authz_grantee_kind::GranteeKind::User)
                || (*principal_kind
                    == ::connetto_schema::authz_grantee_kind::GranteeKind::Installation))
            {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::organization_blocks::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::organization_blocks::principal_kind::NAME],
                        "principal_kind IN ('user', 'installation')",
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        organization_blocks, ::connetto_schema::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        organization_blocks, ::connetto_schema::organizations
    );
}
#[cfg(feature = "models")]
pub use organization_blocks_model::*;
#[cfg(feature = "models")]
pub mod organizations_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(belongs_to(connetto_schema::User, foreign_key = created_by_id))]
    #[table_model(foreign_key((created_by_id), (::connetto_schema::users::id)))]
    #[table_model(
        foreign_key(
            (id, kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = organizations)]
    pub struct Organization {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        created_by_id: ::rosetta_uuid::Uuid,
        ///Set by the first admin grant on the organization. Its creator takes the founding membership and grant only while it is NULL.
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        founded_at: Option<::rosetta_utc::TimestampUTC>,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        organizations, ::connetto_schema::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        organizations, ::connetto_schema::users
    );
}
#[cfg(feature = "models")]
pub use organizations_model::*;
#[cfg(feature = "models")]
pub mod ownables_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(belongs_to(connetto_schema::User, foreign_key = created_by_id))]
    #[table_model(foreign_key((created_by_id), (::connetto_schema::users::id)))]
    #[table_model(
        foreign_key(
            (organization_id, id, kind),
            (
                ::connetto_schema::resources::organization_id,
                ::connetto_schema::resources::id,
                ::connetto_schema::resources::kind
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, project_id, project_kind),
            (
                ::connetto_schema::resources::organization_id,
                ::connetto_schema::resources::id,
                ::connetto_schema::resources::kind
            )
        )
    )]
    #[diesel(table_name = ownables)]
    pub struct Ownable {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema::authz_resource_kind::ResourceKind,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        project_id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        project_kind: ::connetto_schema::authz_resource_kind::ResourceKind,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        created_by_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(ownables::id, ownables::project_id);
    ::diesel::allow_tables_to_appear_in_same_query!(
        ownables, ::connetto_schema::resources
    );
    ::diesel::allow_tables_to_appear_in_same_query!(ownables, ::connetto_schema::users);
}
#[cfg(feature = "models")]
pub use ownables_model::*;
#[cfg(feature = "models")]
pub mod platform_audit_events_model {
    #[derive(Clone, Debug, Hash, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Changes to users, organizations and platform operators, which no organization can hold, since deleting an organization removes its admins.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(surrogate_key)]
    #[diesel(table_name = platform_audit_events)]
    pub struct PlatformAuditEvent {
        id: i64,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        at: ::rosetta_utc::TimestampUTC,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        actor_id: Option<::rosetta_uuid::Uuid>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        original_actor_id: Option<::rosetta_uuid::Uuid>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        installation_id: Option<::rosetta_uuid::Uuid>,
        table_name: String,
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema::authz_audit_operation::sql_types::AuditOperation
        )]
        operation: ::connetto_schema::authz_audit_operation::AuditOperation,
        #[infallible]
        #[diesel(sql_type = ::diesel::sql_types::Jsonb)]
        old_row: Option<::serde_json::Value>,
        #[infallible]
        #[diesel(sql_type = ::diesel::sql_types::Jsonb)]
        new_row: Option<::serde_json::Value>,
    }
    impl ::diesel_builders::ValidateColumn<platform_audit_events::table_name>
    for <platform_audit_events::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(table_name: &String) -> Result<(), Self::Error> {
            use diesel::Column;
            if table_name.is_empty() {
                return Err(
                    ::validation_errors::ValidationError::empty(
                        <crate::platform_audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::platform_audit_events::table_name::NAME,
                    ),
                );
            }
            if table_name.chars().count() > 63usize {
                return Err(
                    ::validation_errors::ValidationError::exceeds_max_length(
                        <crate::platform_audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::platform_audit_events::table_name::NAME,
                        63usize,
                    ),
                );
            }
            Ok(())
        }
    }
    impl ::diesel_builders::ValidateRecord<platform_audit_events::table>
    for <platform_audit_events::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(operation), Some(old_row), Some(new_row)) = (
                <Self as diesel_builders::MayGetColumn<
                    platform_audit_events::operation,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    platform_audit_events::old_row,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    platform_audit_events::new_row,
                >>::may_get_column_ref(self),
            ) {
                if (*operation
                    == ::connetto_schema::authz_audit_operation::AuditOperation::Insert)
                    != old_row.as_ref().is_none()
                {
                    return Err(
                        ::validation_errors::ValidationError::check_violated(
                            <crate::platform_audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                            &[
                                crate::platform_audit_events::operation::NAME,
                                crate::platform_audit_events::old_row::NAME,
                            ],
                            "(operation = 'INSERT') = (old_row IS NULL)",
                        ),
                    );
                }
                if (*operation
                    == ::connetto_schema::authz_audit_operation::AuditOperation::Delete)
                    != new_row.as_ref().is_none()
                {
                    return Err(
                        ::validation_errors::ValidationError::check_violated(
                            <crate::platform_audit_events::table as ::diesel_builders::TableExt>::TABLE_NAME,
                            &[
                                crate::platform_audit_events::operation::NAME,
                                crate::platform_audit_events::new_row::NAME,
                            ],
                            "(operation = 'DELETE') = (new_row IS NULL)",
                        ),
                    );
                }
            }
            Ok(())
        }
    }
}
#[cfg(feature = "models")]
pub use platform_audit_events_model::*;
#[cfg(feature = "models")]
pub mod platform_operators_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(ancestors(connetto_schema::users))]
    #[diesel(belongs_to(connetto_schema::User, foreign_key = id))]
    #[table_model(foreign_key((id), (::connetto_schema::users::id)))]
    #[diesel(table_name = platform_operators)]
    pub struct PlatformOperator {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
    }
    impl ::diesel_builders::GetColumn<connetto_schema::users::id> for PlatformOperator {
        fn get_column_ref(
            &self,
        ) -> &<platform_operators::id as ::diesel_builders::ColumnTyped>::ColumnType {
            &self.id
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        platform_operators, ::connetto_schema::users
    );
}
#[cfg(feature = "models")]
pub use platform_operators_model::*;
#[cfg(feature = "models")]
pub mod resource_parents_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(
        foreign_key(
            (organization_id, id, resource_kind),
            (
                ::connetto_schema::resources::organization_id,
                ::connetto_schema::resources::id,
                ::connetto_schema::resources::kind
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, parent_id, parent_kind),
            (
                ::connetto_schema::resources::organization_id,
                ::connetto_schema::resources::id,
                ::connetto_schema::resources::kind
            )
        )
    )]
    #[diesel(table_name = resource_parents)]
    pub struct ResourceParent {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        resource_kind: ::connetto_schema::authz_resource_kind::ResourceKind,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        parent_id: ::rosetta_uuid::Uuid,
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        parent_kind: ::connetto_schema::authz_resource_kind::ResourceKind,
    }
    impl ::diesel_builders::ValidateColumn<resource_parents::resource_kind>
    for <resource_parents::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(
            resource_kind: &::connetto_schema::authz_resource_kind::ResourceKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*resource_kind
                == ::connetto_schema::authz_resource_kind::ResourceKind::Folder)
                || (*resource_kind
                    == ::connetto_schema::authz_resource_kind::ResourceKind::Project))
            {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::resource_parents::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::resource_parents::resource_kind::NAME],
                        "resource_kind IN ('folder', 'project')",
                    ),
                );
            }
            Ok(())
        }
    }
    impl ::diesel_builders::ValidateColumn<resource_parents::parent_kind>
    for <resource_parents::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(
            parent_kind: &::connetto_schema::authz_resource_kind::ResourceKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*parent_kind
                == ::connetto_schema::authz_resource_kind::ResourceKind::Organization)
                || (*parent_kind
                    == ::connetto_schema::authz_resource_kind::ResourceKind::Folder))
            {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::resource_parents::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::resource_parents::parent_kind::NAME],
                        "parent_kind IN ('organization', 'folder')",
                    ),
                );
            }
            Ok(())
        }
    }
    impl ::diesel_builders::ValidateRecord<resource_parents::table>
    for <resource_parents::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(parent_id), Some(id)) = (
                <Self as diesel_builders::MayGetColumn<
                    resource_parents::parent_id,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    resource_parents::id,
                >>::may_get_column_ref(self),
            ) && parent_id == id
            {
                return Err(
                    ::validation_errors::ValidationError::equal(
                        <crate::resource_parents::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::resource_parents::parent_id::NAME,
                        crate::resource_parents::id::NAME,
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        resource_parents, ::connetto_schema::resources
    );
}
#[cfg(feature = "models")]
pub use resource_parents_model::*;
#[cfg(feature = "models")]
pub mod resources_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[diesel(table_name = resources)]
    pub struct Resource {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema::authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema::authz_resource_kind::ResourceKind,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        archived_at: Option<::rosetta_utc::TimestampUTC>,
        #[table_model(default = false)]
        #[infallible]
        writers_can_share: bool,
    }
    ::diesel_builders::prelude::unique_index!(resources::organization_id, resources::id);
    ::diesel_builders::prelude::unique_index!(
        resources::organization_id, resources::id, resources::kind
    );
    impl ::diesel_builders::ValidateRecord<resources::table>
    for <resources::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(kind), Some(id), Some(organization_id)) = (
                <Self as diesel_builders::MayGetColumn<
                    resources::kind,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    resources::id,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    resources::organization_id,
                >>::may_get_column_ref(self),
            )
                && (*kind
                    == ::connetto_schema::authz_resource_kind::ResourceKind::Organization)
                    != (*id == *organization_id)
            {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::resources::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[
                            crate::resources::kind::NAME,
                            crate::resources::id::NAME,
                            crate::resources::organization_id::NAME,
                        ],
                        "(kind = 'organization') = (id = organization_id)",
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        resources, ::connetto_schema::organizations
    );
}
#[cfg(feature = "models")]
pub use resources_model::*;
#[cfg(feature = "models")]
pub mod share_links_model {
    #[derive(Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[diesel(belongs_to(connetto_schema::User, foreign_key = created_by_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(foreign_key((created_by_id), (::connetto_schema::users::id)))]
    #[table_model(
        foreign_key(
            (id, kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = share_links)]
    pub struct ShareLink {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        token_hash: Vec<u8>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: Option<::rosetta_utc::TimestampUTC>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        revoked_at: Option<::rosetta_utc::TimestampUTC>,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        created_by_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(share_links::token_hash);
    impl ::diesel_builders::ValidateColumn<share_links::token_hash>
    for <share_links::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(token_hash: &Vec<u8>) -> Result<(), Self::Error> {
            use diesel::Column;
            if token_hash.len() != 32usize {
                return Err(
                    ::validation_errors::ValidationError::check_violated(
                        <crate::share_links::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        &[crate::share_links::token_hash::NAME],
                        "octet_length(token_hash) = 32",
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        share_links, ::connetto_schema::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        share_links, ::connetto_schema::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        share_links, ::connetto_schema::users
    );
}
#[cfg(feature = "models")]
pub use share_links_model::*;
#[cfg(feature = "models")]
pub mod team_members_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(primary_key(team_id, user_id))]
    #[table_model(
        foreign_key(
            (organization_id, team_id),
            (::connetto_schema::teams::organization_id, ::connetto_schema::teams::id)
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, user_id),
            (
                ::connetto_schema::memberships::organization_id,
                ::connetto_schema::memberships::user_id
            )
        )
    )]
    #[diesel(table_name = team_members)]
    pub struct TeamMember {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        team_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        user_id: ::rosetta_uuid::Uuid,
        #[diesel(sql_type = ::connetto_schema::authz_team_role::sql_types::TeamRole)]
        team_role: ::connetto_schema::authz_team_role::TeamRole,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        team_members, ::connetto_schema::memberships
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        team_members, ::connetto_schema::teams
    );
}
#[cfg(feature = "models")]
pub use team_members_model::*;
#[cfg(feature = "models")]
pub mod team_parents_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(
        foreign_key(
            (organization_id, id),
            (::connetto_schema::teams::organization_id, ::connetto_schema::teams::id)
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, parent_id),
            (::connetto_schema::teams::organization_id, ::connetto_schema::teams::id)
        )
    )]
    #[diesel(table_name = team_parents)]
    pub struct TeamParent {
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        parent_id: ::rosetta_uuid::Uuid,
    }
    impl ::diesel_builders::ValidateRecord<team_parents::table>
    for <team_parents::table as ::diesel_builders::TableExt>::NewValues {
        #[inline]
        fn validate_record(&self) -> Result<(), ::validation_errors::ValidationError> {
            use diesel::Column;
            if let (Some(parent_id), Some(id)) = (
                <Self as diesel_builders::MayGetColumn<
                    team_parents::parent_id,
                >>::may_get_column_ref(self),
                <Self as diesel_builders::MayGetColumn<
                    team_parents::id,
                >>::may_get_column_ref(self),
            ) && parent_id == id
            {
                return Err(
                    ::validation_errors::ValidationError::equal(
                        <crate::team_parents::table as ::diesel_builders::TableExt>::TABLE_NAME,
                        crate::team_parents::parent_id::NAME,
                        crate::team_parents::id::NAME,
                    ),
                );
            }
            Ok(())
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        team_parents, ::connetto_schema::teams
    );
}
#[cfg(feature = "models")]
pub use team_parents_model::*;
#[cfg(feature = "models")]
pub mod teams_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel::Associations,
        ::diesel_builders::prelude::TableModel
    )]
    #[diesel(belongs_to(connetto_schema::Organization, foreign_key = organization_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema::organizations::id))
    )]
    #[table_model(
        foreign_key(
            (id, kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = teams)]
    pub struct Team {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(teams::organization_id, teams::id);
    ::diesel::allow_tables_to_appear_in_same_query!(teams, ::connetto_schema::grantees);
    ::diesel::allow_tables_to_appear_in_same_query!(
        teams, ::connetto_schema::organizations
    );
}
#[cfg(feature = "models")]
pub use teams_model::*;
#[cfg(feature = "models")]
pub mod users_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    #[table_model(
        foreign_key(
            (id, kind),
            (::connetto_schema::grantees::id, ::connetto_schema::grantees::kind)
        )
    )]
    #[diesel(table_name = users)]
    pub struct User {
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema::authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema::authz_grantee_kind::GranteeKind,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(users, ::connetto_schema::grantees);
}
#[cfg(feature = "models")]
pub use users_model::*;
