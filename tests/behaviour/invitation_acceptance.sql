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

INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
SELECT set_config('app.verified_email', 'c@example.com', true);
SELECT throws_ok($statement$UPDATE invitations SET accepted_by_id = '10000000-0000-7000-8000-000000000002' WHERE id = '70000000-0000-7000-8000-000000000003'$statement$, '42501', NULL, 'client cannot mark an invitation accepted');

SELECT throws_ok($statement$INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000003'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'invitation admits only its organization');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
