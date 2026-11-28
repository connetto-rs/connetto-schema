\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(17);

-- How a write fails once every deferred check has run, with nothing kept.
CREATE FUNCTION pg_temp.failure(statement TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  state TEXT;
  message TEXT;
BEGIN
  BEGIN
    EXECUTE statement;
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'succeeded';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS state = RETURNED_SQLSTATE, message = MESSAGE_TEXT;
  END;
  SET CONSTRAINTS ALL DEFERRED;
  RETURN state || ' ' || message;
END
$$;
GRANT EXECUTE ON FUNCTION pg_temp.failure(TEXT) TO app;

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002',
  '10000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000004', '10000000-0000-7000-8000-000000000005',
  '10000000-0000-7000-8000-000000000006');

-- Organization 2 holds a team and an app the members of organization 1 cannot read.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES ('80000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', 'Elsewhere');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;

-- User 5 founds organization 3 with user 1 as a member, so user 1 reads user 5.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000005');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000005'), '20000000-0000-7000-8000-000000000003');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000005'), '20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;

-- In organization 1, user 4 is a member administering folder 1 only, and user 5 holds organization admin without a membership.
-- Folder 2 holds a project with an ownable user 4 cannot read, and team 1 sits under team 3.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '40000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000004');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000006');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'admin', '10000000-0000-7000-8000-000000000004');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'admin', '10000000-0000-7000-8000-000000000005');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000004', 'member');
INSERT INTO invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id) VALUES
  ('90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'invitee@example.com', now() + interval '7 days', '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'Here');

SELECT throws_ok($statement$INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'active')$statement$, '42501', NULL, 'admin cannot add a member without an invitation');

SELECT is(pg_temp.failure($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', '10000000-0000-7000-8000-000000000003')$statement$),
  pg_temp.failure($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', 'e0000000-0000-7000-8000-000000000001')$statement$),
  'sharing with a user the sharer cannot read fails as with a missing user');
SELECT is(pg_temp.failure($statement$INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', 'team', 'reader')$statement$),
  pg_temp.failure($statement$INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), 'e0000000-0000-7000-8000-000000000001', 'team', 'reader')$statement$),
  'sharing with a team the sharer cannot read fails as with a missing team');
SELECT lives_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', '10000000-0000-7000-8000-000000000004');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', 'team', 'reader');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'organization', 'reader');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('50000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'bc3cf2e2-768c-4af9-bf86-65f23378a212', (SELECT id FROM grantees WHERE kind = 'signed_in'), 'signed_in', 'reader')$statement$,
  'admin shares with a member, a team and the organization it reads, and with signed-in users');

SELECT is(pg_temp.failure($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003')$statement$),
  pg_temp.failure($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'e0000000-0000-7000-8000-000000000001')$statement$),
  'blocking a user the admin cannot read fails as with a missing user');
SELECT lives_ok($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000006')$statement$, 'admin blocks a member');
RESET ROLE;

-- The holder of an invitation to organization 1
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT set_config('app.verified_email', 'invitee@example.com', false);
SET ROLE app;
SELECT is(pg_temp.failure($statement$INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state, invitation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003', 'active', '90000000-0000-7000-8000-000000000001')$statement$),
  pg_temp.failure($statement$INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state, invitation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'e0000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'active', '90000000-0000-7000-8000-000000000001')$statement$),
  'accepting an invitation under another organization fails as under a missing one');
RESET ROLE;

-- The admin of folder 1 only
SELECT pg_temp.act('10000000-0000-7000-8000-000000000004');
SET ROLE app;
SELECT is(pg_temp.failure($statement$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000001' WHERE id = '60000000-0000-7000-8000-000000000002'$statement$),
  pg_temp.failure($statement$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000001' WHERE id = 'e0000000-0000-7000-8000-000000000001'$statement$),
  'moving an unreadable ownable matches moving a missing resource');
RESET ROLE;

-- The organization admin without a membership reads what it administers
SELECT pg_temp.act('10000000-0000-7000-8000-000000000005');
SET ROLE app;
SELECT results_eq($query$SELECT namespace_id, id FROM teams ORDER BY namespace_id, id$query$,
  $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001'::uuid), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003'::uuid)$expected$, 'admin without a membership reads its teams');
SELECT results_eq($query$SELECT namespace_id, id, parent_namespace_id, parent_id FROM teams WHERE parent_id IS NOT NULL$query$,
  $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001'::uuid, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003'::uuid)$expected$, 'admin without a membership reads its team edges');
SELECT results_eq($query$SELECT team_namespace_id, team_id, user_id FROM team_members$query$,
  $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001'::uuid, '10000000-0000-7000-8000-000000000004'::uuid)$expected$, 'admin without a membership reads its team members');
SELECT results_eq($query$SELECT user_id FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000001' ORDER BY user_id$query$,
  $expected$VALUES ('10000000-0000-7000-8000-000000000001'::uuid), ('10000000-0000-7000-8000-000000000004'::uuid), ('10000000-0000-7000-8000-000000000006'::uuid)$expected$, 'admin without a membership reads its memberships');
RESET ROLE;

-- An admin of organization 1 blocked by organization 2
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is_empty($query$SELECT 1 FROM apps WHERE id = '80000000-0000-7000-8000-000000000002'$query$, 'the blocked admin cannot read the blocking organization''s app');
SELECT is(pg_temp.failure($statement$INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '81000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$),
  pg_temp.failure($statement$INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '81000000-0000-7000-8000-000000000001', 'e0000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$),
  'installing an app the admin cannot read fails as a missing app');
SELECT lives_ok($statement$INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '81000000-0000-7000-8000-000000000002', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'); SET CONSTRAINTS ALL IMMEDIATE$statement$, 'admin installs an app it reads');
RESET ROLE;

-- User 6 administers team 3 of organization 1 without organization admin
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000006', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000006');
SET ROLE app;
SELECT is(pg_temp.failure($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000003' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-000000000002'$statement$),
  pg_temp.failure($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000003' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = 'e0000000-0000-7000-8000-000000000001'$statement$),
  'moving an unreadable team matches moving a missing team');
SELECT is(pg_temp.failure($statement$INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'member')$statement$),
  pg_temp.failure($statement$INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', 'e0000000-0000-7000-8000-000000000001', 'member')$statement$),
  'a team admin naming a member of another organization fails as a missing member');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
