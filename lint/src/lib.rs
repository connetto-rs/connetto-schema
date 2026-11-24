//! The `SQLippy` and `rls2fga` configuration connetto-schema is written for,
//! shared with schemas applied on top of it.
//!
//! A downstream schema extends [`deployment()`] with its own tenant tables,
//! builds the constrainer with [`constrainer()`], adds its own allowances,
//! and reads the remaining diagnostics with `diagnostics`. The
//! [`translation`] module holds the `rls2fga` side.

pub use rls2fga;
pub use sqlippy;
use sqlippy::prelude::*;
pub use sqlparser;

pub mod translation;

/// The table whose `id` names a tenant.
pub const TENANT_ROOT: &str = "organizations";

/// Columns whose value, once set, is never cleared, each beside its table.
pub const IRREVERSIBLE_COLUMNS: &[(&str, &str)] = &[("share_links", "revoked_at")];

/// Tables whose rows belong to the organization named by their
/// `organization_id`.
pub const TENANT_TABLES: &[&str] = &[
    "invitations",
    "memberships",
    "teams",
    "team_parents",
    "team_members",
    "resources",
    "resource_parents",
    "ownables",
    "grants",
    "share_links",
    "organization_blocks",
    "apps",
    "app_installations",
    "installation_permissions",
    "audit_events",
];

/// Lint groups raised to [`Level::Warn`] beside the default ones.
pub const RAISED_GROUPS: [LintGroup; 2] = [LintGroup::Pedantic, LintGroup::Restriction];

/// The deployment connetto-schema is written for, over the parsed cluster
/// bootstrap in `cluster/roles.sql`.
///
/// # Panics
///
/// Panics if `SQLippy` cannot parse one of the credential or request
/// setting expressions written below.
#[must_use]
pub fn deployment(cluster: &ParserDB) -> Deployment {
    let mut deployment = Deployment::default()
        .with_cluster_bootstrap(cluster)
        .with_app_role("app")
        .with_app_role("identity_writer")
        .with_pooled(true)
        .with_tenant_key("public", TENANT_ROOT, "id")
        .with_audit_function(
            "authz_write",
            "record_audit_event",
            [WriteEvent::Insert, WriteEvent::Update, WriteEvent::Delete],
        )
        .with_audit_function(
            "authz_write",
            "record_platform_audit_event",
            [WriteEvent::Insert, WriteEvent::Update, WriteEvent::Delete],
        )
        .without_self_asserted_sources()
        .without_binary_replication_tables();
    for (table, column) in IRREVERSIBLE_COLUMNS {
        deployment = deployment.with_irreversible_column("public", *table, *column);
    }
    for table in TENANT_TABLES {
        deployment = deployment.with_tenant_key("public", *table, "organization_id");
    }
    for credential in [
        "authz.caller_id()",
        "NULLIF(current_setting('app.user_id', true), '')::uuid",
        "authz.verified_email()",
    ] {
        deployment = deployment
            .with_credential(credential)
            .expect("credential parses");
    }
    deployment
        .with_request_setting("authz.acting_installation_id()")
        .expect("request setting parses")
}

/// A constrainer reading `deployment` at the levels connetto-schema runs,
/// with the findings it keeps on purpose excused.
#[must_use]
pub fn constrainer(deployment: Deployment) -> DefaultConstrainer<ParserDB> {
    let mut constrainer = DefaultConstrainer::<ParserDB>::default();
    constrainer.set_deployment(deployment);
    for group in RAISED_GROUPS {
        constrainer.set_group_level(group, Level::Warn);
    }
    allow(&mut constrainer);
    constrainer
}

/// Excuses the findings the schema keeps on purpose.
fn allow(constrainer: &mut DefaultConstrainer<ParserDB>) {
    let table = |name| TargetName::new(name, false);
    // Removing a membership removes its team memberships
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("team_members"),
        "team_members_organization_id_user_id_fkey",
    );
    // Removing a grantee removes the grants naming it
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("grants"),
        "grants_grantee_id_grantee_kind_fkey",
    );
    // Removing a principal removes the blocks naming it
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("organization_blocks"),
        "organization_blocks_principal_id_principal_kind_fkey",
    );
    // Whoever deletes a resource administers it, and sharable_grants lets that admin delete every grant on it
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("grants"),
        "grants_organization_id_resource_id_fkey",
    );
    // Deleting a folder or project needs organization admin, which also administers its parent as the edge policy asks
    for key in [
        "resource_parents_organization_id_id_fkey",
        "resource_parents_id_resource_kind_fkey",
    ] {
        constrainer.allow_foreign_key(
            "cascade_into_row_level_security_table",
            table("resource_parents"),
            key,
        );
    }
    // Apart from the two seeded audiences, subtype triggers write every grantee row beside an audited subtype row
    constrainer.allow_table("unaudited_authority_table", table("grantees"));
    // Organization admin needs a grant to the caller, since the grants check keeps everyone, signed_in and link grantees below admin
    for (policy_table, policy) in [
        ("memberships", "memberships_insert"),
        ("team_members", "team_members_insert"),
    ] {
        constrainer.allow_policy("self_granting_write", table(policy_table), policy);
    }
    // Each insert policy pins the column beside the key to an organization or project the caller already sees
    for (index_table, index) in [
        ("invitations", "invitations_organization_id_id_key"),
        ("ownables", "ownables_id_project_id_key"),
    ] {
        constrainer.allow_index(
            "unscoped_unique_constraint_on_row_level_security_table",
            table(index_table),
            index,
        );
    }
    // Only the caller's own unaccepted invitation passes memberships_insert, so the policy refuses before the key is checked
    constrainer.allow_index(
        "unscoped_unique_constraint_on_row_level_security_table",
        table("memberships"),
        "memberships_invitation_id_key",
    );
    // A link token hash names one link across all organizations, and guessing one is guessing a 256-bit secret
    constrainer.allow_index(
        "unscoped_unique_constraint_on_row_level_security_table",
        table("share_links"),
        "share_links_token_hash_key",
    );
}
