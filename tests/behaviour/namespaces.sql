\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(23);

SELECT has_table('public', 'namespaces', 'namespace registry exists');
SELECT is((SELECT count(*) FROM namespaces WHERE reserved), 1::bigint, 'one reserved namespace exists');
SELECT throws_ok($statement$INSERT INTO namespaces (id, reserved) VALUES (gen_random_uuid(), true)$statement$, '23505', NULL, 'another reserved namespace is refused');

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
SELECT throws_ok($statement$INSERT INTO namespaces (id, user_id) VALUES (gen_random_uuid(), '10000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'identity writer cannot insert namespaces directly');
RESET ROLE;
SELECT is((SELECT count(*) FROM namespaces WHERE user_id IS NOT NULL), 2::bigint, 'each provisioned user receives a namespace');
SELECT is((SELECT count(DISTINCT id) FROM namespaces), 3::bigint, 'users and reserved namespace have distinct identities');
SELECT throws_ok($statement$INSERT INTO namespaces (id, user_id) VALUES (gen_random_uuid(), '10000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'a user cannot hold a second namespace');
SELECT id AS first_namespace FROM namespaces WHERE user_id = '10000000-0000-7000-8000-000000000001' \gset
SELECT id AS second_namespace FROM namespaces WHERE user_id = '10000000-0000-7000-8000-000000000002' \gset
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is(authz.caller_namespace(), :'first_namespace'::uuid, 'caller receives its own namespace');
SELECT throws_ok(format('INSERT INTO namespaces (id, user_id) VALUES (%L, %L)', :'second_namespace', '10000000-0000-7000-8000-000000000001'), '42501', NULL, 'client cannot claim another namespace');
SELECT throws_ok(format('UPDATE namespaces SET user_id = %L WHERE id = %L', '10000000-0000-7000-8000-000000000001', :'second_namespace'), '42501', NULL, 'client cannot reassign another namespace');
SELECT throws_ok(format('DELETE FROM namespaces WHERE id = %L', :'second_namespace'), '42501', NULL, 'client cannot remove another namespace');
SELECT throws_ok('SELECT authz_write.insert_namespace()', '42501', NULL, 'client cannot invoke provisioning directly');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT is(authz.caller_namespace(), :'second_namespace'::uuid, 'changing caller resolves the other namespace');
SELECT pg_temp.act(NULL);
SELECT is(authz.caller_namespace(), NULL::uuid, 'anonymous caller has no namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT is(authz.caller_namespace(), NULL::uuid, 'unprovisioned caller has no namespace');
RESET ROLE;
SELECT throws_ok($statement$INSERT INTO namespaces (user_id, reserved) VALUES ('10000000-0000-7000-8000-000000000003', true)$statement$, '23514', NULL, 'a reserved namespace cannot belong to a user');
SELECT lives_ok($statement$DELETE FROM users WHERE id = '10000000-0000-7000-8000-000000000001'$statement$, 'owner can delete a provisioned user');
SELECT is((SELECT count(*) FROM namespaces WHERE id = :'first_namespace'::uuid AND user_id IS NULL AND NOT reserved), 1::bigint, 'namespace survives detached from its deleted user');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'deleted user cannot read its detached namespace');
SELECT is(authz.caller_namespace(), NULL::uuid, 'deleted user has no caller namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'another user cannot read the detached namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'unprovisioned user cannot read the detached namespace');
SELECT pg_temp.act(NULL);
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'anonymous caller cannot read the detached namespace');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
