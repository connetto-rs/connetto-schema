//!Auto-generated crate for the `app_installations`, `apps` and `installation_permissions` tables.
extern crate self as connetto_schema_apps;
///Items generated for the `app_installations` table.
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
    ///Struct representing a row in the `app_installations` table.
    #[diesel(belongs_to(connetto_schema_apps::App, foreign_key = app_id))]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[table_model(foreign_key((app_id), (::connetto_schema_apps::apps::id)))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[table_model(
        foreign_key(
            (id, kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = app_installations)]
    pub struct AppInstallation {
        ///Field representing the `id` column in table `app_installations`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `app_installations`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `app_id` column in table `app_installations`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        app_id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `app_installations`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(
        app_installations::organization_id, app_installations::id
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema_apps::apps
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        app_installations, ::connetto_schema_grantees::organizations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use app_installations_model::*;
///Items generated for the `apps` table.
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
    ///Struct representing a row in the `apps` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[diesel(table_name = apps)]
    pub struct App {
        ///Field representing the `id` column in table `apps`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `apps`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `name` column in table `apps`.
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
        apps, ::connetto_schema_grantees::organizations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use apps_model::*;
///Items generated for the `installation_permissions` table.
pub mod installation_permissions_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `installation_permissions` table.
    #[diesel(primary_key(installation_id, kind))]
    #[table_model(
        foreign_key(
            (organization_id, installation_id),
            (
                ::connetto_schema_apps::app_installations::organization_id,
                ::connetto_schema_apps::app_installations::id
            )
        )
    )]
    #[diesel(table_name = installation_permissions)]
    pub struct InstallationPermission {
        ///Field representing the `installation_id` column in table `installation_permissions`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        installation_id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `installation_permissions`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `installation_permissions`.
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema_authz_resource_kind::ResourceKind,
        ///Field representing the `max_role` column in table `installation_permissions`.
        #[diesel(sql_type = ::connetto_schema_authz_role::sql_types::Role)]
        max_role: ::connetto_schema_authz_role::Role,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        installation_permissions, ::connetto_schema_apps::app_installations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use installation_permissions_model::*;
