\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(5);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO organizations (namespace_id, id, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES
  ('20000000-0000-7000-8000-000000000001', 'organization', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SAVEPOINT client_grant;
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES
  ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'admin')$statement$,
  '42501', NULL, 'the client cannot write the founding grant');
ROLLBACK TO SAVEPOINT client_grant;
INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
SELECT results_eq($query$SELECT organization_namespace_id, organization_id, resource_id, user_id, role::text FROM user_grants$query$,
  $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'::uuid, '20000000-0000-7000-8000-000000000001'::uuid,
    '10000000-0000-7000-8000-000000000001'::uuid, 'admin'::text)$expected$,
  'the founder membership writes exactly one admin grant');
SELECT isnt((SELECT founded_at FROM organizations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000001'),
  NULL::timestamptz, 'the founder membership stamps founded_at');
RESET ROLE;
INSERT INTO organizations (namespace_id, id, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES
  ('20000000-0000-7000-8000-000000000002', 'organization', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002');
INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'active');
SELECT is_empty($query$SELECT 1 FROM user_grants WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000002'$query$,
  'a non-founder membership writes no grant');
UPDATE organizations SET founded_at = now() WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000002';
INSERT INTO memberships (organization_namespace_id, organization_id, user_id, state) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'active');
SELECT is_empty($query$SELECT 1 FROM user_grants WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000002'$query$,
  'a founded organization receives no founding grant');
SELECT * FROM finish();
ROLLBACK;
