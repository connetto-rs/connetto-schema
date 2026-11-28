setup
{
  INSERT INTO users (id) VALUES ('00000000-0000-0000-0000-000000000002'), ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000006');
  SET app.user_id = '00000000-0000-0000-0000-000000000002';
  BEGIN;
  INSERT INTO organizations (namespace_id, id, created_by_id) VALUES ((SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
  INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES ('00000000-0000-0000-0000-000000000001', 'organization', (SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001');
  INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES ((SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'active');
  COMMIT;
  INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES ((SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'active');
  INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES ((SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000004', (SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001'), ((SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000005', (SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001');
  INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  VALUES ('00000000-0000-0000-0000-000000000001', (SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002'), '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'admin');
}

session first
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; }
step first_begin { BEGIN ISOLATION LEVEL REPEATABLE READ; }
step first_write { INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES ('00000000-0000-0000-0000-000000000001', (SELECT authz.caller_namespace()), '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'reader'); }
step first_finish { COMMIT; }

session second
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; }
step second_begin { BEGIN ISOLATION LEVEL REPEATABLE READ; }
step second_snapshot { SELECT id FROM users WHERE id = '00000000-0000-0000-0000-000000000006'; }
step second_write { INSERT INTO platform_operators (id) VALUES ('00000000-0000-0000-0000-000000000006'); }
step second_finish { ROLLBACK; }

session observer
step invariant { SELECT count(*) AS permanent_operator_grants FROM user_grants permission JOIN platform_operators operator ON operator.id = permission.user_id WHERE operator.id = '00000000-0000-0000-0000-000000000006' AND permission.expires_at IS NULL; }

permutation first_begin first_write second_begin second_snapshot first_finish second_write second_finish invariant
