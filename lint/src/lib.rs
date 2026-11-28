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
/// `organization_namespace_id` and `organization_id` together.
pub const TENANT_TABLES: &[&str] = &[
    "invitations",
    "memberships",
    "teams",
    "team_members",
    "resources",
    "grants",
    "user_grants",
    "share_links",
    "user_blocks",
    "installation_blocks",
    "apps",
    "app_installations",
    "installation_permissions",
    "audit_events",
];

/// Lint groups raised to [`Level::Warn`] beside the default ones.
pub const RAISED_GROUPS: [LintGroup; 2] = [LintGroup::Pedantic, LintGroup::Restriction];

/// Helper sets each yielding only values the second yields. Every helper
/// tests `role >= min_role`, an organization grant is a grant on the
/// organization's own resource, and a team admin holds an active membership.
pub const SETS_WITHIN: &[(&str, &str)] = &[
    (
        "authz.organizations_with('admin')",
        "authz.organizations_with('reader')",
    ),
    (
        "authz.organizations_with('reader')",
        "authz.organizations_reaching('reader')",
    ),
    (
        "authz.organizations_reaching('admin')",
        "authz.organizations_reaching('writer')",
    ),
    (
        "authz.organizations_reaching('writer')",
        "authz.organizations_reaching('reader')",
    ),
    (
        "authz.team_admin_organizations()",
        "authz.member_organizations()",
    ),
    (
        "authz.resources_with('admin')",
        "authz.resources_with('writer')",
    ),
    (
        "authz.resources_with('writer')",
        "authz.resources_with('reader')",
    ),
    (
        "authz.capped_kinds('admin')",
        "authz.capped_kinds('writer')",
    ),
    (
        "authz.capped_kinds('writer')",
        "authz.capped_kinds('reader')",
    ),
];

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
        .with_tenant_key("public", TENANT_ROOT, ["namespace_id", "id"])
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
        deployment = deployment.with_tenant_key(
            "public",
            *table,
            ["organization_namespace_id", "organization_id"],
        );
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
    for (narrower, wider) in SETS_WITHIN {
        deployment = deployment
            .with_set_within(narrower, wider)
            .expect("helper set parses");
    }
    deployment
        .with_request_setting("authz.acting_installation_id()")
        .expect("request setting parses")
        .with_request_setting("authz.acting_installation_namespace_id()")
        .expect("request namespace setting parses")
        .with_principal_accessor("authz.caller_namespace()")
        .expect("principal accessor parses")
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
    // An organization installs apps that other organizations publish
    constrainer.allow_foreign_key(
        "tenant_local_reference",
        table("app_installations"),
        "app_installations_app_id_fkey",
    );
    constrainer.allow_foreign_key(
        "tenant_local_reference",
        table("installation_blocks"),
        "installation_blocks_installation_namespace_id_installation_fkey",
    );
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("installation_blocks"),
        "installation_blocks_installation_namespace_id_installation_fkey",
    );
    // Removing a membership removes its team memberships
    constrainer.allow_foreign_key(
        "cascade_into_row_level_security_table",
        table("team_members"),
        "team_members_organization_namespace_id_organization_id_use_fkey",
    );
    // Archive copies remain equal through the cascading resource key.
    for (key_table, key) in [
        (
            "grants",
            "grants_organization_namespace_id_organization_id_resource__fkey",
        ),
        (
            "user_grants",
            "user_grants_organization_namespace_id_organization_id_reso_fkey",
        ),
        ("resources", "resources_parent_archive_fkey"),
    ] {
        constrainer.allow_foreign_key(
            "cascade_into_row_level_security_table",
            table(key_table),
            key,
        );
    }
    constrainer.allow_foreign_key(
        "copied_column_through_superkey",
        table("grants"),
        "grants_organization_namespace_id_organization_id_resource__fkey",
    );
    constrainer.allow_foreign_key(
        "copied_column_through_superkey",
        table("user_grants"),
        "user_grants_organization_namespace_id_organization_id_reso_fkey",
    );
    // Published apps form one catalog every caller reads, and apps_blocked hides only the apps of organizations blocking the caller
    constrainer.allow_policy("deny_list_policy", table("apps"), "apps_blocked");
    // Each insert policy pins the column beside the key to an organization or project the caller already sees
    constrainer.allow_index(
        "unscoped_unique_constraint_on_row_level_security_table",
        table("invitations"),
        "invitations_organization_namespace_id_organization_id_id_key",
    );
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
    // No role writes owned_namespace_id, which every user takes from gen_random_uuid()
    constrainer.allow_index(
        "unscoped_unique_constraint_on_row_level_security_table",
        table("users"),
        "users_owned_namespace_id_key",
    );
    // A bearer reads back only the link ids it presented, kept while unrevoked and unexpired, which share_links_select hides from it
    constrainer.allow_function(
        "exposed_definer_over_protected_table",
        table("caller_grantees").with_schema("authz", false),
    );
    // app moves resources only through this view, whose condition and cascaded check option decide each move, so it reads as its owner by design
    for rule in ["owner_rights_view", "owner_rights_view_exposed"] {
        constrainer.allow_view(rule, table("resource_moves"));
    }
}
