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
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step first_begin { BEGIN ISOLATION LEVEL REPEATABLE READ; }
step first_snapshot { SELECT count(*) FROM grants; }
step first_write { INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005'); }
step first_finish { ROLLBACK; }

session second
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step second_begin { BEGIN ISOLATION LEVEL REPEATABLE READ; }
step second_snapshot { SELECT count(*) FROM grants; }
step second_write { INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000004'); }
step second_finish { ROLLBACK; }

session observer
step invariant { SELECT count(*) AS cycles FROM team_parents first_edge JOIN team_parents second_edge ON first_edge.id = second_edge.parent_id AND first_edge.parent_id = second_edge.id WHERE first_edge.organization_id = '00000000-0000-0000-0000-000000000001'; }

permutation first_begin first_snapshot second_begin second_snapshot first_write first_finish second_write second_finish invariant
