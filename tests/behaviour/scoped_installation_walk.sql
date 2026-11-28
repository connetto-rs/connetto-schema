\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'project', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('40000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001',
  '40000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'files app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'organization', 'reader'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'ownable', 'reader');
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, true);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', true);

SELECT results_eq($query$SELECT id FROM resources WHERE kind = 'ownable'$query$,
  $$VALUES ('40000000-0000-7000-8000-000000000003'::UUID)$$, 'installation reads the ownable inside the folder it cannot read');
SELECT is_empty($query$SELECT 1 FROM resources WHERE kind IN ('folder', 'project')$query$, 'installation cannot read the folder or the project');
SELECT throws_ok($query$SELECT authz.containers_with('reader', true)$query$, '42501', NULL,
  'installation cannot list the containers its scope hides');
SELECT throws_ok($query$SELECT authz.reached_with('reader', true)$query$, '42501', NULL,
  'installation cannot list the resources its scope hides');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
