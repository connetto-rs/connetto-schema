\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(12);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002'), ('10000000-0000-7000-8000-000000000003');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000003', 'project', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin'),
  ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'user', 'reader'),
  ('50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'user', 'reader'),
  ('50000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SAVEPOINT project_deletion;
SELECT lives_ok($statement$DELETE FROM resources WHERE id = '50000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, 'a project deletion removes its ownable');
ROLLBACK TO project_deletion;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;

SELECT throws_ok($statement$DELETE FROM resource_moves WHERE id = '60000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'move view cannot delete a resource');
SELECT lives_ok($statement$DELETE FROM resources WHERE id = '60000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'admin through a direct grant deletes an ownable that holds grants');

RESET ROLE;
SELECT is_empty($query$SELECT id FROM resources WHERE kind = 'ownable' AND id = '60000000-0000-7000-8000-000000000001'$query$, 'ownable deletion removes its resource');
SELECT is_empty($query$SELECT resource_id FROM grants WHERE resource_id = '60000000-0000-7000-8000-000000000001'$query$, 'ownable deletion removes its grants');
SELECT results_eq($query$SELECT count(*)::int FROM audit_events WHERE table_name = 'grants' AND operation = 'DELETE' AND old_row ->> 'resource_id' = '60000000-0000-7000-8000-000000000001'$query$, $expected$VALUES (2)$expected$, 'each removed grant is audited');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT lives_ok($statement$DELETE FROM resources WHERE id = '50000000-0000-7000-8000-000000000002'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'organization admin deletes a project that holds a grant');

RESET ROLE;
SELECT is_empty($query$SELECT id FROM resources WHERE id = '50000000-0000-7000-8000-000000000002' UNION ALL SELECT resource_id FROM grants WHERE resource_id = '50000000-0000-7000-8000-000000000002'$query$, 'project deletion removes its row and grants');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SAVEPOINT folder_deletion;
SELECT lives_ok($statement$DELETE FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, 'a folder deletion removes its child');
ROLLBACK TO folder_deletion;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT is_empty($query$DELETE FROM resources WHERE id = '50000000-0000-7000-8000-000000000003' RETURNING id$query$, 'project admin without organization admin cannot delete the project');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
DELETE FROM resources WHERE id = '50000000-0000-7000-8000-000000000003';
SELECT lives_ok($statement$DELETE FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, 'organization admin deletes an empty folder');
RESET ROLE;
SELECT is_empty($query$SELECT id FROM resources WHERE kind IN ('folder', 'project') AND id = '40000000-0000-7000-8000-000000000001'$query$, 'folder deletion removes its row');
SELECT * FROM finish();
ROLLBACK;
