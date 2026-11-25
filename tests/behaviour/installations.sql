\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(5);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
INSERT INTO teams (id, organization_id) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002'),
  ('30000000-0000-7000-8000-000000000005', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'admin');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', true);

SELECT is_empty($query$SELECT 1 FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'$query$, 'installation cannot read another organization');

SELECT is_empty($query$SELECT 1 FROM authz.member_organizations() organization_id WHERE organization_id = '20000000-0000-7000-8000-000000000002'$query$, 'membership helper stays in installation organization');

SELECT is_empty($query$SELECT 1 FROM authz.administered_teams() team_id WHERE team_id = '30000000-0000-7000-8000-000000000004'$query$, 'team administration stays in installation organization');

SELECT is_empty($query$SELECT 1 FROM grantees WHERE id IN ('20000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000004')$query$, 'grantees stay in installation organization');

SELECT is_empty($query$UPDATE resources SET writers_can_share = TRUE WHERE id = '40000000-0000-7000-8000-000000000003' RETURNING *$query$, 'installation cannot write another organization');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
