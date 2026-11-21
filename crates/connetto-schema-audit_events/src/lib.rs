//!Auto-generated crate for the `audit_events` table.
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
    ///Field representing the `id` column in table `audit_events`.
    id: i64,
    ///Field representing the `at` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::rosetta_utc::diesel_impls::TimestampUTC)]
    at: ::rosetta_utc::TimestampUTC,
    ///Field representing the `organization_id` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
    organization_id: ::rosetta_uuid::Uuid,
    ///Field representing the `actor_id` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
    actor_id: Option<::rosetta_uuid::Uuid>,
    ///Field representing the `original_actor_id` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
    original_actor_id: Option<::rosetta_uuid::Uuid>,
    ///Field representing the `installation_id` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::rosetta_uuid::diesel_impls::Uuid)]
    installation_id: Option<::rosetta_uuid::Uuid>,
    ///Field representing the `table_name` column in table `audit_events`.
    table_name: String,
    ///Field representing the `operation` column in table `audit_events`.
    #[infallible]
    #[diesel(
        sql_type = ::connetto_schema_authz_audit_operation::sql_types::AuditOperation
    )]
    operation: ::connetto_schema_authz_audit_operation::AuditOperation,
    ///Field representing the `old_row` column in table `audit_events`.
    #[infallible]
    #[diesel(sql_type = ::diesel::sql_types::Jsonb)]
    old_row: Option<::serde_json::Value>,
    ///Field representing the `new_row` column in table `audit_events`.
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
                == ::connetto_schema_authz_audit_operation::AuditOperation::Insert)
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
                == ::connetto_schema_authz_audit_operation::AuditOperation::Delete)
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
