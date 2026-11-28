\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(7);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000003');
INSERT INTO invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', 'b@example.com', false);
SET ROLE app;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT id FROM invitations$query$, $expected$VALUES ('70000000-0000-7000-8000-000000000001'::uuid)$expected$, 'invitee sees invitation');
SELECT pg_temp.accept_invitation('70000000-0000-7000-8000-000000000001');
SELECT results_eq($query$SELECT accepted_by_id FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$query$, $expected$VALUES ('10000000-0000-7000-8000-000000000002'::uuid)$expected$, 'server marks the invitation accepted');
SELECT results_eq($query$SELECT organization_namespace_id, organization_id, user_id FROM memberships ORDER BY user_id$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'::uuid, '10000000-0000-7000-8000-000000000001'::uuid), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'::uuid, '10000000-0000-7000-8000-000000000002'::uuid)$expected$, 'member sees memberships');
SELECT is_empty($query$SELECT id FROM resources WHERE kind = 'project'$query$, 'member without a grant cannot see projects');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id, accepted_by_id) VALUES
    ('70000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'forged@example.com', now() + interval '1 day',
      '10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002')$statement$, '42501', NULL, 'invitation acceptance cannot be forged');
SELECT throws_ok($statement$DELETE FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$statement$, CASE WHEN current_setting('server_version_num')::int >= 180000 THEN '23001' ELSE '23503' END, NULL, 'accepted invitation stays while its member stays');
DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
    DELETE FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001';
SELECT is_empty($query$SELECT 1 FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$query$, 'accepted invitation can be deleted once its member leaves');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
