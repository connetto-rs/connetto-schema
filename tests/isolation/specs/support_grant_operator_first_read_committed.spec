setup
{
  INSERT INTO users (id) VALUES ('00000000-0000-0000-0000-000000000002'), ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000006');
  SET app.user_id = '00000000-0000-0000-0000-000000000002';
  BEGIN;
  INSERT INTO organizations (id, created_by_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000001', 'organization', '00000000-0000-0000-0000-000000000001');
  INSERT INTO memberships (organization_id, user_id, state) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'active');
  COMMIT;
  INSERT INTO memberships (organization_id, user_id, state) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'active');
  INSERT INTO teams (id, organization_id) VALUES ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001');
  INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'user', 'admin');
}

session first
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; }
step first_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step first_write { INSERT INTO platform_operators (id) VALUES ('00000000-0000-0000-0000-000000000006'); }
step first_finish { COMMIT; }

session second
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; }
step second_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step second_write { INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'user', 'reader'); }
step second_finish { ROLLBACK; }

session observer
step invariant { SELECT count(*) AS permanent_operator_grants FROM grants permission JOIN platform_operators operator ON operator.id = permission.grantee_id WHERE operator.id = '00000000-0000-0000-0000-000000000006' AND permission.expires_at IS NULL; }

permutation first_begin first_write second_begin second_write first_finish second_finish invariant
