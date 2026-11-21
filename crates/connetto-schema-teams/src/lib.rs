//!Auto-generated crate for the `invitations`, `memberships`, `team_members`, `team_parents` and `teams` tables.
extern crate self as connetto_schema_teams;
///Items generated for the `invitations` table.
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
    ///Struct representing a row in the `invitations` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[table_model(foreign_key((invited_by_id), (::connetto_schema_grantees::users::id)))]
    #[table_model(
        foreign_key((accepted_by_id), (::connetto_schema_grantees::users::id))
    )]
    #[diesel(table_name = invitations)]
    pub struct Invitation {
        ///Field representing the `id` column in table `invitations`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `invitations`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `email` column in table `invitations`.
        email: String,
        ///Field representing the `expires_at` column in table `invitations`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
        expires_at: ::rosetta_utc::TimestampUTC,
        ///Field representing the `invited_by_id` column in table `invitations`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        invited_by_id: ::rosetta_uuid::Uuid,
        ///Field representing the `accepted_by_id` column in table `invitations`.
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
        invitations, ::connetto_schema_grantees::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        invitations, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use invitations_model::*;
///Items generated for the `memberships` table.
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
    ///Struct representing a row in the `memberships` table.
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
    #[diesel(belongs_to(connetto_schema_grantees::User, foreign_key = user_id))]
    #[diesel(primary_key(organization_id, user_id))]
    #[table_model(
        foreign_key((organization_id), (::connetto_schema_grantees::organizations::id))
    )]
    #[table_model(foreign_key((user_id), (::connetto_schema_grantees::users::id)))]
    #[table_model(
        foreign_key(
            (organization_id, invitation_id),
            (
                ::connetto_schema_teams::invitations::organization_id,
                ::connetto_schema_teams::invitations::id
            )
        )
    )]
    #[diesel(table_name = memberships)]
    pub struct Membership {
        ///Field representing the `organization_id` column in table `memberships`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `user_id` column in table `memberships`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        user_id: ::rosetta_uuid::Uuid,
        ///Field representing the `state` column in table `memberships`.
        #[diesel(
            sql_type = ::connetto_schema_authz_membership_state::sql_types::MembershipState
        )]
        state: ::connetto_schema_authz_membership_state::MembershipState,
        ///Field representing the `invitation_id` column in table `memberships`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        invitation_id: Option<::rosetta_uuid::Uuid>,
    }
    ::diesel_builders::prelude::unique_index!(memberships::invitation_id);
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema_teams::invitations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema_grantees::organizations
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        memberships, ::connetto_schema_grantees::users
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use memberships_model::*;
///Items generated for the `team_members` table.
pub mod team_members_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `team_members` table.
    #[diesel(primary_key(team_id, user_id))]
    #[table_model(
        foreign_key(
            (organization_id, team_id),
            (
                ::connetto_schema_teams::teams::organization_id,
                ::connetto_schema_teams::teams::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, user_id),
            (
                ::connetto_schema_teams::memberships::organization_id,
                ::connetto_schema_teams::memberships::user_id
            )
        )
    )]
    #[diesel(table_name = team_members)]
    pub struct TeamMember {
        ///Field representing the `team_id` column in table `team_members`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        team_id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `team_members`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `user_id` column in table `team_members`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        user_id: ::rosetta_uuid::Uuid,
        ///Field representing the `team_role` column in table `team_members`.
        #[diesel(sql_type = ::connetto_schema_authz_team_role::sql_types::TeamRole)]
        team_role: ::connetto_schema_authz_team_role::TeamRole,
    }
    ::diesel::allow_tables_to_appear_in_same_query!(
        team_members, ::connetto_schema_teams::memberships
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        team_members, ::connetto_schema_teams::teams
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use team_members_model::*;
///Items generated for the `team_parents` table.
pub mod team_parents_model {
    #[derive(Copy, Clone, Debug, Hash, Ord, PartialOrd, Eq, PartialEq)]
    #[derive(::serde::Serialize, ::serde::Deserialize)]
    #[derive(
        ::diesel::Queryable,
        ::diesel::Selectable,
        ::diesel::Identifiable,
        ::diesel_builders::prelude::TableModel
    )]
    ///Struct representing a row in the `team_parents` table.
    #[table_model(error = ::validation_errors::ValidationError)]
    #[table_model(record_error = ::validation_errors::ValidationError)]
    #[table_model(
        foreign_key(
            (organization_id, id),
            (
                ::connetto_schema_teams::teams::organization_id,
                ::connetto_schema_teams::teams::id
            )
        )
    )]
    #[table_model(
        foreign_key(
            (organization_id, parent_id),
            (
                ::connetto_schema_teams::teams::organization_id,
                ::connetto_schema_teams::teams::id
            )
        )
    )]
    #[diesel(table_name = team_parents)]
    pub struct TeamParent {
        ///Field representing the `id` column in table `team_parents`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `organization_id` column in table `team_parents`.
        #[infallible]
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
        ///Field representing the `parent_id` column in table `team_parents`.
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
        team_parents, ::connetto_schema_teams::teams
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use team_parents_model::*;
///Items generated for the `teams` table.
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
    ///Struct representing a row in the `teams` table.
    #[diesel(
        belongs_to(connetto_schema_grantees::Organization, foreign_key = organization_id)
    )]
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
    #[diesel(table_name = teams)]
    pub struct Team {
        ///Field representing the `id` column in table `teams`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        id: ::rosetta_uuid::Uuid,
        ///Field representing the `kind` column in table `teams`.
        #[table_model(generated)]
        #[diesel(
            sql_type = ::connetto_schema_authz_grantee_kind::sql_types::GranteeKind
        )]
        kind: ::connetto_schema_authz_grantee_kind::GranteeKind,
        ///Field representing the `organization_id` column in table `teams`.
        #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
        organization_id: ::rosetta_uuid::Uuid,
    }
    ::diesel_builders::prelude::unique_index!(teams::organization_id, teams::id);
    ::diesel::allow_tables_to_appear_in_same_query!(
        teams, ::connetto_schema_grantees::grantees
    );
    ::diesel::allow_tables_to_appear_in_same_query!(
        teams, ::connetto_schema_grantees::organizations
    );
}
#[allow(
    ambiguous_glob_reexports,
    reason = "Tables of one crate can generate the same name, reachable through the module of each table"
)]
pub use teams_model::*;
