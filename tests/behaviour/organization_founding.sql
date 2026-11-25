\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(7);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT id FROM organizations$query$, $expected$VALUES ('20000000-0000-7000-8000-000000000001'::uuid)$expected$, 'founder sees the organization');

SELECT throws_ok($statement$DELETE FROM grants WHERE grantee_id = '10000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', 'organization 20000000-0000-7000-8000-000000000001 would lose its last admin', 'last admin cannot be deleted');

SELECT throws_ok($statement$INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000001'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', 'organization 20000000-0000-7000-8000-000000000005 requires an active admin', 'organization without an admin is refused');

SELECT throws_ok($statement$INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000002')$statement$, '42501', NULL, 'organization creator is the caller');

SELECT throws_ok($statement$INSERT INTO organizations (id, created_by_id, founded_at) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000001', now())$statement$, '42501', NULL, 'organization creator cannot mark it founded');

SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000006');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT isnt((SELECT founded_at FROM organizations WHERE id = '20000000-0000-7000-8000-000000000006'), NULL::timestamptz, 'the founding grant marks the organization founded');

RESET ROLE;
SELECT lives_ok($statement$INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000007', '10000000-0000-7000-8000-000000000001'); DELETE FROM organizations WHERE id = '20000000-0000-7000-8000-000000000007'; SET CONSTRAINTS ALL IMMEDIATE$statement$, 'organization inserted and deleted in one transaction needs no admin');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
