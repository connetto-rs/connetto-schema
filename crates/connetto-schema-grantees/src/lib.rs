//!Auto-generated crate for the `grantees`, `organization_blocks`, `organizations`, `platform_operators`, `share_links` and `users` tables.
extern crate self as connetto_schema_grantees;
///Items generated for the `grantees` table.
pub mod grantees_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `grantees` table.
    #[diesel(table_name = grantees)]
    pub struct Grantee {
        ///Field representing the `id` column in table `grantees`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `grantees`.
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
    }
    ::diesel_builders::prelude::unique_index!(grantees::id, grantees::kind);
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use grantees_model::*;
///Items generated for the `organization_blocks` table.
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
    ///Struct representing a row in the `organization_blocks` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[diesel(primary_key(organization_id, principal_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[table_model(
        foreign_key(
            (principal_id, principal_kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = organization_blocks)]
    pub struct OrganizationBlock {
        ///Field representing the `organization_id` column in table `organization_blocks`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `principal_id` column in table `organization_blocks`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        principal_id: ::rosetta_uuid::Uuid,
        ///Field representing the `principal_kind` column in table `organization_blocks`.
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        principal_kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `expires_at` column in table `organization_blocks`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: Option<::rosetta_utc::TimestampUTC>,
    }
    impl ::diesel_builders::ValidateColumn<organization_blocks::principal_kind>
    for <organization_blocks::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(
            principal_kind: &::connetto_schema_authz_grantee_kind::GranteeKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*principal_kind
                == ::connetto_schema_authz_grantee_kind::GranteeKind::User)
                || (*principal_kind
                    == ::connetto_schema_authz_grantee_kind::GranteeKind::Installation))
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
        organization_blocks, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        organization_blocks, ::connetto_schema_grantees::organizations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use organization_blocks_model::*;
///Items generated for the `organizations` table.
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
    ///Struct representing a row in the `organizations` table.
    #[diesel(belongs_to(connetto_schema_grantees::User, foreign_key = created_by_id))]
    #[table_model(foreign_key((created_by_id), (::connetto_schema_grantees::users::id)))]
    #[table_model(
        foreign_key(
            (id, kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = organizations)]
    pub struct Organization {
        ///Field representing the `id` column in table `organizations`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `organizations`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `created_by_id` column in table `organizations`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        created_by_id: ::rosetta_uuid::Uuid,
        ///Set by the first admin grant on the organization. Its creator takes the founding membership and grant only while it is NULL.
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        founded_at: Option<::rosetta_utc::TimestampUTC>,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        organizations, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        organizations, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use organizations_model::*;
///Items generated for the `platform_operators` table.
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
    ///Struct representing a row in the `platform_operators` table.
    #[table_model(ancestors(connetto_schema_grantees::users))]
    #[diesel(belongs_to(connetto_schema_grantees::User, foreign_key = id))]
    #[table_model(foreign_key((id), (::connetto_schema_grantees::users::id)))]
    #[diesel(table_name = platform_operators)]
    pub struct PlatformOperator {
        ///Field representing the `id` column in table `platform_operators`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
    }
    impl ::diesel_builders::GetColumn<connetto_schema_grantees::users::id>
    for PlatformOperator {
        fn get_column_ref(
            &self,
        ) -> &<platform_operators::id as ::diesel_builders::ColumnTyped>::ColumnType {
            &self.id
        }
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        platform_operators, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use platform_operators_model::*;
///Items generated for the `share_links` table.
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
    ///Struct representing a row in the `share_links` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[diesel(belongs_to(connetto_schema_grantees::User, foreign_key = created_by_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[table_model(foreign_key((created_by_id), (::connetto_schema_grantees::users::id)))]
    #[table_model(
        foreign_key(
            (id, kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = share_links)]
    pub struct ShareLink {
        ///Field representing the `id` column in table `share_links`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `share_links`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `organization_id` column in table `share_links`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `token_hash` column in table `share_links`.
        token_hash: Vec<u8>,
        ///Field representing the `expires_at` column in table `share_links`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: Option<::rosetta_utc::TimestampUTC>,
        ///Field representing the `revoked_at` column in table `share_links`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        revoked_at: Option<::rosetta_utc::TimestampUTC>,
        ///Field representing the `created_by_id` column in table `share_links`.
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
        share_links, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        share_links, ::connetto_schema_grantees::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        share_links, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use share_links_model::*;
///Items generated for the `users` table.
pub mod users_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `users` table.
    #[table_model(
        foreign_key(
            (id, kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = users)]
    pub struct User {
        ///Field representing the `id` column in table `users`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `users`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        users, ::connetto_schema_grantees::grantees
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use users_model::*;
