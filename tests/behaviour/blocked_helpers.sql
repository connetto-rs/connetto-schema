\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(23);

-- User 1 founds organization 1 with folder 1, project 1 and ownable 1, where user 2 is a member,
-- team admin, organization admin and holder of a second pending invitation. User 3 founds organization 2 and shares
-- project 2 with organization 1. User 2 starts organization 3. Organizations 1 and 3
-- then block user 2.
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002'),
  ('10000000-0000-7000-8000-000000000003');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES
  ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES
  ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002@example.com',
    now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000002');
RESET ROLE;
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES
  ('20000000-0000-7000-8000-000000000002', '50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', 'organization', 'reader');

SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- Organization 3 stays unfounded, which its deferred admin check allows until commit.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000002');
RESET ROLE;
INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES
  ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user'),
  ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000002', 'user'),
  ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'user');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', '10000000-0000-7000-8000-000000000002@example.com', false);
SET ROLE app;
SELECT is_empty($query$SELECT 1 FROM authz.member_organizations() organization WHERE organization = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked member is a member of no blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.caller_grantees() grantee
  WHERE grantee IN ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001')$query$,
  'a blocked member holds no grantee of the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.co_member_users() member WHERE member = '10000000-0000-7000-8000-000000000001'$query$,
  'a blocked member has no co-members through the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.administered_teams() team WHERE team = '30000000-0000-7000-8000-000000000001'$query$,
  'a blocked member administers no team of the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.team_admin_organizations() organization WHERE organization = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked team admin administers teams in no blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.granted_resources('reader') resource WHERE resource = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked member is granted no resource of the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.resources_with('reader') resource
  WHERE resource IN ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002')$query$,
  'a blocked member holds no role through the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.sharable_grants() share WHERE share.resource_id = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked admin shares nothing in the blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.organizations_reaching('reader') organization WHERE organization = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked member reaches into no blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.organizations_with('reader') organization WHERE organization = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked member holds no role on a blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.founded_organizations() organization WHERE organization = '20000000-0000-7000-8000-000000000003'$query$,
  'a blocked creator founds no blocking organization');
SELECT is_empty($query$SELECT 1 FROM authz.pending_invitations() pending WHERE pending.organization_id = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked member holds no pending invitation of the blocking organization');
SELECT is_empty($query$SELECT 1 FROM resources WHERE id = '50000000-0000-7000-8000-000000000002'$query$,
  'a blocked member loses resources other organizations shared with the blocking organization');
SELECT is_empty($query$SELECT 1 FROM users WHERE id = '10000000-0000-7000-8000-000000000001'$query$,
  'a blocked member no longer reads the other members of the blocking organization');
SELECT is_empty($query$SELECT 1 FROM resources WHERE organization_id = '20000000-0000-7000-8000-000000000001'
  UNION ALL SELECT 1 FROM resource_parents WHERE organization_id = '20000000-0000-7000-8000-000000000001'
  UNION ALL SELECT 1 FROM ownables WHERE organization_id = '20000000-0000-7000-8000-000000000001'$query$,
  'a blocked admin reads no resource, edge or ownable of the blocking organization');
SELECT throws_ok($statement$INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001', 'folder')$statement$,
  '42501', NULL, 'a blocked admin creates no folder in the blocking organization');
SELECT is_empty($query$UPDATE resources SET archived_at = now() WHERE organization_id = '20000000-0000-7000-8000-000000000001' RETURNING id$query$,
  'a blocked admin archives nothing in the blocking organization');
SELECT is_empty($query$UPDATE ownables SET project_id = project_id WHERE organization_id = '20000000-0000-7000-8000-000000000001' RETURNING id$query$,
  'a blocked admin moves no ownable of the blocking organization');
DELETE FROM organization_blocks WHERE principal_id = '10000000-0000-7000-8000-000000000002';
SELECT results_eq($query$SELECT organization_id FROM organization_blocks ORDER BY organization_id$query$,
  $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID), ('20000000-0000-7000-8000-000000000003')$values$,
  'a blocked user reads its own blocks and no one else''s');
RESET ROLE;
SELECT is((SELECT count(*) FROM organization_blocks WHERE principal_id = '10000000-0000-7000-8000-000000000002'), 2::BIGINT,
  'a blocked user cannot lift its own blocks');
SET ROLE app;
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SELECT is_empty($query$SELECT 1 FROM authz.capped_kinds('reader') capped WHERE capped.organization_id = '20000000-0000-7000-8000-000000000001'$query$,
  'an installation acting for a blocked user holds no capability in a blocking organization');
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT results_eq($query$SELECT id FROM resources WHERE id = '50000000-0000-7000-8000-000000000002'$query$,
  $values$VALUES ('50000000-0000-7000-8000-000000000002'::UUID)$values$,
  'an unblocked member keeps resources shared with the organization');
SELECT results_eq($query$SELECT id FROM users WHERE id = '10000000-0000-7000-8000-000000000002'$query$,
  $values$VALUES ('10000000-0000-7000-8000-000000000002'::UUID)$values$,
  'an unblocked member still reads a blocked member');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
