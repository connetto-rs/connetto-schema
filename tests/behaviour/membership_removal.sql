\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(3);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000003', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', 'organization');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000004', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000005', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000004', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'admin');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES
  ('20000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001';
SELECT is_empty($query$SELECT 1 FROM authz.resources_with('admin') resource_id WHERE resource_id = '20000000-0000-7000-8000-000000000002'$query$, 'removed member loses direct admin');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id) VALUES
  ('90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', 'member@example.com', now() + interval '7 days', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
UPDATE memberships SET state = 'deactivated' WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001';
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SELECT set_config('app.verified_email', 'member@example.com', false);
SET ROLE app;
SELECT is_empty($query$DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001' RETURNING *$query$, 'deactivated member cannot delete its membership');
SELECT throws_ok($statement$SELECT pg_temp.accept_invitation('90000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'deactivated member cannot reactivate through a pending invitation');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
