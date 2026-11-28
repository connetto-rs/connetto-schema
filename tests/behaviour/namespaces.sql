\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(23);

SELECT has_table('public', 'namespaces', 'namespace registry exists');
SELECT is((SELECT count(*) FROM namespaces WHERE reserved), 1::bigint, 'one reserved namespace exists');
SELECT throws_ok($statement$INSERT INTO namespaces (id, reserved) VALUES (gen_random_uuid(), true)$statement$, '23514', NULL, 'another reserved namespace is refused');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000002');
SELECT throws_ok($statement$INSERT INTO namespaces DEFAULT VALUES$statement$, '42501', NULL, 'identity writer cannot insert namespaces directly');
RESET ROLE;
SELECT is((SELECT count(*) FROM namespaces WHERE NOT reserved), 2::bigint, 'each provisioned user receives a namespace');
SELECT is((SELECT count(DISTINCT id) FROM namespaces), 3::bigint, 'users and reserved namespace have distinct identities');
SELECT owned_namespace_id AS first_namespace FROM users WHERE id = '10000000-0000-7000-8000-000000000001' \gset
SELECT owned_namespace_id AS second_namespace FROM users WHERE id = '10000000-0000-7000-8000-000000000002' \gset
SELECT throws_ok(format('UPDATE users SET owned_namespace_id = %L WHERE id = %L', :'second_namespace', '10000000-0000-7000-8000-000000000001'), '23505', NULL, 'a user cannot share another user''s namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is((SELECT authz.caller_namespace()), :'first_namespace'::uuid, 'caller receives its own namespace');
SELECT throws_ok(format('INSERT INTO namespaces (id) VALUES (%L)', :'second_namespace'), '42501', NULL, 'client cannot claim another namespace');
SELECT throws_ok(format('UPDATE namespaces SET reserved = true WHERE id = %L', :'second_namespace'), '42501', NULL, 'client cannot reassign another namespace');
SELECT throws_ok(format('DELETE FROM namespaces WHERE id = %L', :'second_namespace'), '42501', NULL, 'client cannot remove another namespace');
SELECT throws_ok('SELECT authz_write.insert_namespace()', '42501', NULL, 'client cannot invoke provisioning directly');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT is((SELECT authz.caller_namespace()), :'second_namespace'::uuid, 'changing caller resolves the other namespace');
SELECT pg_temp.act(NULL);
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'anonymous caller has no namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'unprovisioned caller has no namespace');
RESET ROLE;
SELECT lives_ok($statement$DELETE FROM users WHERE id = '10000000-0000-7000-8000-000000000001'$statement$, 'owner can delete a provisioned user');
SELECT is((SELECT count(*) FROM namespaces WHERE id = :'first_namespace'::uuid AND NOT reserved), 1::bigint, 'namespace survives detached from its deleted user');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'deleted user cannot read its detached namespace');
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'deleted user has no caller namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'another user cannot read the detached namespace');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'unprovisioned user cannot read the detached namespace');
SELECT pg_temp.act(NULL);
SELECT is_empty(format('SELECT id FROM namespaces WHERE id = %L', :'first_namespace'), 'anonymous caller cannot read the detached namespace');
SELECT results_eq($query$SELECT id FROM namespaces$query$, $expected$VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212'::uuid)$expected$, 'anonymous caller reads only the reserved namespace');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
