//! The `rls2fga` configuration connetto-schema is written for, under which
//! every policy clause has to translate at confidence A.
//!
//! A downstream schema confirms its own attribute columns and declares its
//! own helpers on the [`registry`] before building the [`translator`].

use rls2fga::{
    classifier::function_registry::FunctionRegistry,
    parser::sql_parser::{
        DatabaseLike, Deployment, FunctionLike, ParserDB, SessionSetting, SetPacking, SettingValue,
    },
    translator::{PlanningError, Translator, TranslatorBuilder},
    types::{ConfidenceLevel, TranslationNote},
};
use sqlparser::ast::DataType;

/// Row columns whose literal checks and comparisons decide access, each with
/// its table.
pub const ATTRIBUTE_COLUMNS: &[(&str, &str)] = &[
    ("grantees", "kind"),
    ("grants", "role"),
    ("grants", "grantee_kind"),
    ("grants", "organization_id"),
    ("grants", "resource_id"),
    ("grants", "resource_archived"),
    ("invitations", "accepted_by_id"),
    ("invitations", "expires_at"),
    ("memberships", "invitation_id"),
    ("memberships", "state"),
    ("ownables", "archived"),
    ("ownables", "project_archived"),
    ("resource_parents", "archived"),
    ("resource_parents", "parent_archived"),
    ("resources", "kind"),
    ("resources", "archived"),
    ("resources", "archived_at"),
    ("resources", "inherits_archive"),
    ("resources", "writers_can_share"),
    ("share_links", "revoked_at"),
];

/// The roles requests run as and the session settings the policies read.
///
/// # Panics
///
/// Panics if `rls2fga` refuses one of the settings declared below.
#[must_use]
pub fn deployment() -> Deployment {
    let settings = [
        SessionSetting::value("app.user_id", SettingValue::Caller(DataType::Uuid))
            .expect("caller setting")
            .may_be_unset(),
        SessionSetting::value("app.installation_id", SettingValue::Scalar(DataType::Uuid))
            .expect("installation setting")
            .may_be_unset(),
        SessionSetting::value(
            "app.link_ids",
            SettingValue::Set {
                element: DataType::Uuid,
                packing: SetPacking::Delimited(",".into()),
            },
        )
        .expect("link setting")
        .may_be_unset(),
        SessionSetting::value("app.verified_email", SettingValue::Scalar(DataType::Text))
            .expect("email setting")
            .may_be_unset(),
    ];
    Deployment::new("app", ["app"], settings).expect("deployment")
}

/// A registry confirming [`ATTRIBUTE_COLUMNS`] and declaring every
/// set-returning helper of the `authz` schema in `database`.
#[must_use]
pub fn registry(database: &ParserDB) -> FunctionRegistry {
    let mut registry = FunctionRegistry::new();
    for (table, column) in ATTRIBUTE_COLUMNS {
        registry.register_attribute_column(*table, *column);
    }
    registry.declare_helpers(
        database
            .functions()
            .filter(|function| {
                function.target_name().schema() == Some("authz") && function.returns_set()
            })
            .map(|function| format!("authz.{}", function.name())),
    );
    registry
}

/// A translator for `deployment` and `registry` that treats any clause
/// below confidence A as diverging from the database.
#[must_use]
pub fn translator(deployment: Deployment, registry: FunctionRegistry) -> Translator {
    TranslatorBuilder::new(deployment)
        .with_registry(registry)
        .with_min_confidence(ConfidenceLevel::A)
        .build()
}

/// The notes on which the model `translator` builds for `database` diverges
/// from `PostgreSQL`, empty when it answers as the database does.
///
/// # Errors
///
/// Returns the error `rls2fga` raises when it cannot plan the model at all.
pub fn divergences(
    translator: &Translator,
    database: &ParserDB,
) -> Result<Vec<TranslationNote>, PlanningError> {
    Ok(match translator.translate(database)?.outputs() {
        Ok(_) => Vec::new(),
        Err(divergent) => divergent.notes().to_vec(),
    })
}
