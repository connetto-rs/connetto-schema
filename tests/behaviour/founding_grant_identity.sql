\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(5);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO organizations (id, created_by_id) VALUES
  ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
SAVEPOINT client_grant;
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin')$statement$,
  '42501', NULL, 'the client cannot write the founding grant');
ROLLBACK TO SAVEPOINT client_grant;
INSERT INTO memberships (organization_id, user_id, state) VALUES
  ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
SELECT results_eq($query$SELECT organization_id, resource_id, grantee_id, grantee_kind::text, role::text FROM grants$query$,
  $expected$VALUES ('20000000-0000-7000-8000-000000000001'::uuid, '20000000-0000-7000-8000-000000000001'::uuid,
    '10000000-0000-7000-8000-000000000001'::uuid, 'user'::text, 'admin'::text)$expected$,
  'the founder membership writes exactly one admin grant');
SELECT isnt((SELECT founded_at FROM organizations WHERE id = '20000000-0000-7000-8000-000000000001'),
  NULL::timestamptz, 'the founder membership stamps founded_at');
RESET ROLE;
INSERT INTO organizations (id, created_by_id) VALUES
  ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('20000000-0000-7000-8000-000000000002', 'organization', '20000000-0000-7000-8000-000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES
  ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'active');
SELECT is_empty($query$SELECT 1 FROM grants WHERE organization_id = '20000000-0000-7000-8000-000000000002'$query$,
  'a non-founder membership writes no grant');
UPDATE organizations SET founded_at = now() WHERE id = '20000000-0000-7000-8000-000000000002';
INSERT INTO memberships (organization_id, user_id, state) VALUES
  ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'active');
SELECT is_empty($query$SELECT 1 FROM grants WHERE organization_id = '20000000-0000-7000-8000-000000000002'$query$,
  'a founded organization receives no founding grant');
SELECT * FROM finish();
ROLLBACK;
