\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(8);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind, writers_can_share) VALUES
  ('40000000-0000-7000-8000-000000000001', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', false),
  ('40000000-0000-7000-8000-000000000002', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', true),
  ('40000000-0000-7000-8000-000000000003', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', true);
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'member');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', 'team', 'admin');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role)
  SELECT folder.id, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', grantee.namespace_id, grantee.id, 'everyone', 'writer'
  FROM grantees grantee, (VALUES ('40000000-0000-7000-8000-000000000002'::uuid), ('40000000-0000-7000-8000-000000000003'::uuid)) folder(id)
  WHERE grantee.kind = 'everyone';
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES
  ('40000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'reader');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'sharing app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'organization', 'admin');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  SELECT '40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin'$statement$,
  '42501', NULL, 'an admin through a team cannot grant itself a direct role');
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  SELECT '40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'writer'$statement$,
  '42501', NULL, 'a writer through an audience cannot grant itself a direct role');
SELECT is_empty($query$UPDATE user_grants SET role = 'writer' WHERE user_id = '10000000-0000-7000-8000-000000000002' RETURNING *$query$, 'a sharer cannot raise its own direct grant');
SELECT lives_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  SELECT '40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'admin'$statement$,
  'an admin through a team still grants another member');
RESET ROLE;

SELECT pg_temp.act(NULL);
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  SELECT '40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'writer'$statement$,
  '42501', NULL, 'a caller without a user cannot grant one a direct role through an audience');
RESET ROLE;
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, false);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role)
  SELECT '40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'writer'$statement$,
  '42501', NULL, 'an installation acting alone cannot grant a user a direct role');
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
DELETE FROM team_members WHERE user_id = '10000000-0000-7000-8000-000000000002';
DELETE FROM grants WHERE grantee_kind = 'everyone';
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT ok(NOT ('40000000-0000-7000-8000-000000000001'::uuid IN (SELECT authz.resources_with('admin'))), 'leaving the team ends the admin role');
SELECT ok(NOT ('40000000-0000-7000-8000-000000000002'::uuid IN (SELECT authz.resources_with('writer'))), 'removing the audience grant ends the writer role');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
