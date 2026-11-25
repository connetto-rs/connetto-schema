\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'project', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('40000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001',
  '40000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'files app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'reader'),
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'ownable', 'reader');
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', true);

SELECT results_eq($query$SELECT id FROM resources WHERE kind = 'ownable'$query$,
  $$VALUES ('40000000-0000-7000-8000-000000000003'::UUID)$$, 'installation reads the ownable inside the folder it cannot read');
SELECT is_empty($query$SELECT 1 FROM resources WHERE kind IN ('folder', 'project')$query$, 'installation cannot read the folder or the project');
SELECT throws_ok($query$SELECT authz.containers_with('reader')$query$, '42501', NULL,
  'installation cannot list the containers its scope hides');
SELECT throws_ok($query$SELECT authz.reached_with('reader')$query$, '42501', NULL,
  'installation cannot list the resources its scope hides');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
