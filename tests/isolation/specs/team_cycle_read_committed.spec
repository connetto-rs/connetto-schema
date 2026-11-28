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
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step first_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step first_write { UPDATE teams SET parent_namespace_id = (SELECT authz.caller_namespace()), parent_id = '00000000-0000-0000-0000-000000000005' WHERE namespace_id = (SELECT authz.caller_namespace()) AND organization_namespace_id = (SELECT authz.caller_namespace()) AND organization_id = '00000000-0000-0000-0000-000000000001' AND id = '00000000-0000-0000-0000-000000000004'; }
step first_finish { COMMIT; }

session second
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step second_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step second_write { UPDATE teams SET parent_namespace_id = (SELECT authz.caller_namespace()), parent_id = '00000000-0000-0000-0000-000000000004' WHERE namespace_id = (SELECT authz.caller_namespace()) AND organization_namespace_id = (SELECT authz.caller_namespace()) AND organization_id = '00000000-0000-0000-0000-000000000001' AND id = '00000000-0000-0000-0000-000000000005'; }
step second_finish { ROLLBACK; }

session observer
step invariant { SELECT count(*) AS cycles FROM teams first_edge JOIN teams second_edge ON first_edge.namespace_id = second_edge.parent_namespace_id AND first_edge.id = second_edge.parent_id AND first_edge.parent_namespace_id = second_edge.namespace_id AND first_edge.parent_id = second_edge.id WHERE first_edge.organization_namespace_id = (SELECT owned_namespace_id FROM users WHERE id = '00000000-0000-0000-0000-000000000002') AND first_edge.organization_id = '00000000-0000-0000-0000-000000000001'; }

permutation first_begin first_write second_begin second_write first_finish second_finish invariant
