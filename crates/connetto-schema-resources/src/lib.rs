//!Auto-generated crate for the `grants`, `ownables`, `resource_parents` and `resources` tables.
extern crate self as connetto_schema_resources;
///Items generated for the `grants` table.
pub mod grants_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `grants` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[diesel(primary_key(resource_id, grantee_id))]
    #[table_model(
        foreign_key(
            (organization_id, resource_id),
            (
                ::connetto_schema_resources::resources::organization_id,
                ::connetto_schema_resources::resources::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (grantee_id, grantee_kind),
            (
                ::connetto_schema_grantees::grantees::id,
                ::connetto_schema_grantees::grantees::kind
            )
        )
    )]
    #[diesel(table_name = grants)]
    pub struct Grant {
        ///Field representing the `resource_id` column in table `grants`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        resource_id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `grants`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `grantee_id` column in table `grants`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        grantee_id: ::rosetta_uuid::Uuid,
        ///Field representing the `grantee_kind` column in table `grants`.
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        grantee_kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `role` column in table `grants`.
        #[infallible]
        #[diesel(sql_type = ::connetto_schema_authz_role::sql_types::Role)]
        role: ::connetto_schema_authz_role::Role,
        ///Field representing the `expires_at` column in table `grants`.
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
                    != ::connetto_schema_authz_grantee_kind::GranteeKind::Everyone)
                    && (*grantee_kind
                        != ::connetto_schema_authz_grantee_kind::GranteeKind::SignedIn))
                    && (*grantee_kind
                        != ::connetto_schema_authz_grantee_kind::GranteeKind::Link))
                    || (*role < ::connetto_schema_authz_role::Role::Admin))
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
    ::diesel::allow_tables_to_appear_in_same_query!(
        grants, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        grants, ::connetto_schema_resources::resources
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use grants_model::*;
///Items generated for the `ownables` table.
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
    ///Struct representing a row in the `ownables` table.
    #[diesel(belongs_to(connetto_schema_grantees::User, foreign_key = created_by_id))]
    #[table_model(foreign_key((created_by_id), (::connetto_schema_grantees::users::id)))]
    #[table_model(
        foreign_key(
            (id, kind),
            (
                ::connetto_schema_resources::resources::id,
                ::connetto_schema_resources::resources::kind
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, id),
            (
                ::connetto_schema_resources::resources::organization_id,
                ::connetto_schema_resources::resources::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (project_id, project_kind),
            (
                ::connetto_schema_resources::resources::id,
                ::connetto_schema_resources::resources::kind
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, project_id),
            (
                ::connetto_schema_resources::resources::organization_id,
                ::connetto_schema_resources::resources::id
            )
        )
    )]
    #[diesel(table_name = ownables)]
    pub struct Ownable {
        ///Field representing the `id` column in table `ownables`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `ownables`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `ownables`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema_authz_resource_kind::ResourceKind,
        ///Field representing the `project_id` column in table `ownables`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        project_id: ::rosetta_uuid::Uuid,
        ///Field representing the `project_kind` column in table `ownables`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        project_kind: ::connetto_schema_authz_resource_kind::ResourceKind,
        ///Field representing the `created_by_id` column in table `ownables`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        created_by_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(ownables::id, ownables::project_id);
    ::diesel::allow_tables_to_appear_in_same_query!(
        ownables, ::connetto_schema_resources::resources
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        ownables, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use ownables_model::*;
///Items generated for the `resource_parents` table.
pub mod resource_parents_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `resource_parents` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(
        foreign_key(
            (organization_id, id),
            (
                ::connetto_schema_resources::resources::organization_id,
                ::connetto_schema_resources::resources::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, parent_id),
            (
                ::connetto_schema_resources::resources::organization_id,
                ::connetto_schema_resources::resources::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (id, resource_kind),
            (
                ::connetto_schema_resources::resources::id,
                ::connetto_schema_resources::resources::kind
            )
        )
    )]
    #[table_model(
        foreign_key(
            (parent_id, parent_kind),
            (
                ::connetto_schema_resources::resources::id,
                ::connetto_schema_resources::resources::kind
            )
        )
    )]
    #[diesel(table_name = resource_parents)]
    pub struct ResourceParent {
        ///Field representing the `id` column in table `resource_parents`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `resource_parents`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `resource_kind` column in table `resource_parents`.
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        resource_kind: ::connetto_schema_authz_resource_kind::ResourceKind,
        ///Field representing the `parent_id` column in table `resource_parents`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        parent_id: ::rosetta_uuid::Uuid,
        ///Field representing the `parent_kind` column in table `resource_parents`.
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        parent_kind: ::connetto_schema_authz_resource_kind::ResourceKind,
    }
    impl ::diesel_builders::ValidateColumn<resource_parents::resource_kind>
    for <resource_parents::table as ::diesel_builders::TableExt>::NewValues {
        type Error = ::validation_errors::ValidationError;
        #[inline]
        fn validate_column(
            resource_kind: &::connetto_schema_authz_resource_kind::ResourceKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*resource_kind
                == ::connetto_schema_authz_resource_kind::ResourceKind::Folder)
                || (*resource_kind
                    == ::connetto_schema_authz_resource_kind::ResourceKind::Project))
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
            parent_kind: &::connetto_schema_authz_resource_kind::ResourceKind,
        ) -> Result<(), Self::Error> {
            use diesel::Column;
            if !((*parent_kind
                == ::connetto_schema_authz_resource_kind::ResourceKind::Organization)
                || (*parent_kind
                    == ::connetto_schema_authz_resource_kind::ResourceKind::Folder))
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
        resource_parents, ::connetto_schema_resources::resources
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use resource_parents_model::*;
///Items generated for the `resources` table.
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
    ///Struct representing a row in the `resources` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[diesel(table_name = resources)]
    pub struct Resource {
        ///Field representing the `id` column in table `resources`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `resources`.
        #[infallible]
        #[diesel(
            sql_type = ::connetto_schema_authz_resource_kind::sql_types::ResourceKind
        )]
        kind: ::connetto_schema_authz_resource_kind::ResourceKind,
        ///Field representing the `organization_id` column in table `resources`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `archived_at` column in table `resources`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        archived_at: Option<::rosetta_utc::TimestampUTC>,
        ///Field representing the `writers_can_share` column in table `resources`.
        #[table_model(default = false)]
        #[infallible]
        writers_can_share: bool,
    }
    ::diesel_builders::prelude::unique_index!(resources::id, resources::kind);
    ::diesel_builders::prelude::unique_index!(resources::organization_id, resources::id);
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
                    == ::connetto_schema_authz_resource_kind::ResourceKind::Organization)
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
        resources, ::connetto_schema_grantees::organizations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use resources_model::*;
