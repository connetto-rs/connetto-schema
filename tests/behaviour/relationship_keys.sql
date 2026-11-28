\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(6);

-- User 2 founds organization 2 with team 2, where user 3 is a member, and installation 2 with a project permission.
-- User 1 founds organization 1, where user 3 is also a member.
SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002',
  '10000000-0000-7000-8000-000000000003');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003', 'member');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', 'hidden app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '90000000-0000-7000-8000-000000000002', '80000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002');
INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '90000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', 'project', 'writer');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- An admin of organization 1 learns nothing of team 2 or installation 2 by naming them under organization 1.
SELECT is_empty($query$SELECT 1 FROM team_members WHERE team_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND team_id = '30000000-0000-7000-8000-000000000002'
  UNION ALL SELECT 1 FROM installation_permissions WHERE installation_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND installation_id = '90000000-0000-7000-8000-000000000002'$query$,
  'an admin reads no team member or installation permission of another organization');
SELECT throws_ok($statement$INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'member');
  SET CONSTRAINTS ALL IMMEDIATE$statement$,
  '23503', NULL, 'a hidden team member of another organization fails as a missing team does');
SELECT throws_ok($statement$INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'member');
  SET CONSTRAINTS ALL IMMEDIATE$statement$,
  '23503', NULL, 'a member of a missing team fails on the team');
SELECT throws_ok($statement$INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '90000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'project', 'writer');
  SET CONSTRAINTS ALL IMMEDIATE$statement$,
  '23503', NULL, 'a hidden installation permission of another organization fails as a missing installation does');
SELECT throws_ok($statement$INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000009', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'project', 'writer');
  SET CONSTRAINTS ALL IMMEDIATE$statement$,
  '23503', NULL, 'a permission of a missing installation fails on the installation');
RESET ROLE;
SELECT results_eq($query$SELECT organization_namespace_id, organization_id, team_namespace_id, team_id, user_id FROM team_members$query$,
  $values$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002'::UUID, pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002'::UUID, '10000000-0000-7000-8000-000000000003'::UUID)$values$,
  'the hidden team member stays as it was');

SELECT * FROM finish();
ROLLBACK;
