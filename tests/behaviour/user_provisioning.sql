\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(6);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE identity_writer;
SELECT lives_ok($statement$INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001')$statement$, 'identity writer provisions the session user');
SELECT throws_ok($statement$INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000003')$statement$, '42501', NULL, 'identity writer cannot provision another user');
SELECT throws_ok($statement$INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000002') ON CONFLICT DO NOTHING$statement$, '42501', NULL, 'identity writer cannot probe another user through a conflict');
SELECT results_eq($query$SELECT id FROM users$query$, $expected$VALUES ('10000000-0000-7000-8000-000000000001'::uuid)$expected$, 'identity writer reads only the session user');
SELECT pg_temp.act(NULL);
SELECT throws_ok($statement$INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000003')$statement$, '42501', NULL, 'identity writer provisions no user without a session subject');
SELECT is_empty($query$SELECT id FROM users$query$, 'identity writer reads no user without a session subject');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
