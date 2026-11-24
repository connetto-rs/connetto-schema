\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(2);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000003');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', 'b@example.com', false);
SET ROLE app;
SELECT pg_temp.accept_invitation('70000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT throws_ok($statement$WITH removed AS (DELETE FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001' RETURNING id, organization_id)
  INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id)
  SELECT id, organization_id, 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001' FROM removed$statement$,
  CASE WHEN current_setting('server_version_num')::int >= 180000 THEN '23001' ELSE '23503' END, NULL, 'an accepted invitation cannot be re-created as pending');

SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
SELECT set_config('app.verified_email', 'b@example.com', true);
DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
SELECT throws_ok($statement$INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'accepted invitation cannot be reused');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
