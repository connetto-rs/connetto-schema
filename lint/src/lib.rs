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
    for (narrower, wider) in SETS_WITHIN {
        deployment = deployment
            .with_set_within(narrower, wider)
            .expect("helper set parses");
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
    // An organization installs apps that other organizations publish
    constrainer.allow_foreign_key(
        "tenant_local_reference",
        table("app_installations"),
        "app_installations_app_id_fkey",
    );
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
    // resources_insert names only organizations from organizations_reaching or founded_organizations, which organizations_select reads
    constrainer.allow_foreign_key(
        "foreign_key_existence_oracle",
        table("resources"),
        "resources_organization_id_fkey",
    );
    // Every key into resources carries archived, and ON UPDATE CASCADE keeps the copy each archive policy reads equal to it.
    // Whoever deletes a resource administers it, and sharable_grants lets that admin delete every grant on it.
    // Deleting a folder or project needs organization admin, which also administers its parent as the edge policy asks.
    // Deleting an ownable resource needs admin on it, which also reads its ownable.
    for (key_table, key) in [
        (
            "grants",
            "grants_organization_id_resource_id_resource_archived_fkey",
        ),
        (
            "resource_parents",
            "resource_parents_organization_id_id_resource_kind_archived_fkey",
        ),
        (
            "resource_parents",
            "resource_parents_organization_id_parent_id_parent_kind_par_fkey",
        ),
        ("ownables", "ownables_organization_id_id_kind_archived_fkey"),
        (
            "ownables",
            "ownables_organization_id_project_id_project_kind_project_a_fkey",
        ),
    ] {
        constrainer.allow_foreign_key(
            "cascade_into_row_level_security_table",
            table(key_table),
            key,
        );
        constrainer.allow_foreign_key("copied_column_through_superkey", table(key_table), key);
    }
    // Apart from the two seeded audiences, subtype triggers write every grantee row beside an audited subtype row
    constrainer.allow_table("unaudited_authority_table", table("grantees"));
    // Organization admin needs a grant to the caller, since the grants check keeps everyone, signed_in and link grantees below admin
    constrainer.allow_policy(
        "self_granting_write",
        table("team_members"),
        "team_members_insert",
    );
    // Each insert policy pins the column beside the key to an organization or project the caller already sees
    constrainer.allow_index(
        "unscoped_unique_constraint_on_row_level_security_table",
        table("invitations"),
        "invitations_organization_id_id_key",
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
    // A bearer reads back only the link ids it presented, kept while unrevoked and unexpired, which share_links_select hides from it
    constrainer.allow_function(
        "exposed_definer_over_protected_table",
        table("caller_grantees").with_schema("authz", false),
    );
    // teams_parent_required runs at commit, after the team's parent edge exists, and no policy sees that later row when the team is inserted
    constrainer.allow_table("authorization_in_trigger", table("teams"));
}
