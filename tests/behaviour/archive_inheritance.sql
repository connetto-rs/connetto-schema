\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(21);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '40000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$statement$, '42501', NULL, 'folder archive refuses grants on a nested ownable');
SELECT is_empty($query$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001' RETURNING id$query$, 'folder archive keeps a nested ownable in place');
SELECT is_empty($query$DELETE FROM resources WHERE id = '60000000-0000-7000-8000-000000000001' RETURNING id$query$, 'folder archive keeps a nested ownable');
SELECT is_empty($query$UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001', parent_kind = 'organization' WHERE id = '50000000-0000-7000-8000-000000000001' RETURNING id$query$, 'folder archive keeps a nested project under its folder');
SELECT throws_ok($statement$SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000003', 'folder', '40000000-0000-7000-8000-000000000002')$statement$, '42501', NULL, 'folder archive refuses new folders below it');
SELECT is_empty($query$UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000002' RETURNING id$query$, 'folder below an archive cannot be restored');
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';

UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000002';
UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';
SELECT is_empty($query$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001' RETURNING id$query$, 'restoring an ancestor keeps an archived folder frozen');
SELECT lives_ok($statement$SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000004', 'folder', '40000000-0000-7000-8000-000000000001')$statement$, 'restored folder accepts new folders');
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000002';
SELECT results_eq($query$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001' RETURNING project_id$query$, $expected$VALUES ('50000000-0000-7000-8000-000000000002'::uuid)$expected$, 'restoring every archived ancestor frees the ownable');

UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001';
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$statement$, '42501', NULL, 'organization archive refuses grants on its projects');
UPDATE resources SET archived_at = NULL WHERE id = '20000000-0000-7000-8000-000000000001';
SELECT lives_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$statement$, 'organization restore accepts grants on its projects');

UPDATE resources SET archived_at = now() WHERE id = '60000000-0000-7000-8000-000000000001';
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$statement$, '42501', NULL, 'ownable archive refuses grants on it');
SELECT is_empty($query$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000001' WHERE id = '60000000-0000-7000-8000-000000000001' RETURNING id$query$, 'ownable archive keeps it in place');
UPDATE resources SET archived_at = NULL WHERE id = '60000000-0000-7000-8000-000000000001';
SELECT lives_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$statement$, 'ownable restore accepts grants on it');

UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
RESET ROLE;
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
SELECT lives_ok('SET CONSTRAINTS ALL IMMEDIATE', 'an ownable written into an archived project satisfies its archive keys');
SELECT results_eq($query$SELECT inherits_archive, archived FROM resources WHERE id = '60000000-0000-7000-8000-000000000002'$query$, $expected$VALUES (TRUE, TRUE)$expected$, 'an ownable written into an archived project inherits its archive');
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000005', 'folder', '40000000-0000-7000-8000-000000000002');
SELECT lives_ok('SET CONSTRAINTS ALL IMMEDIATE', 'a folder written below an archived folder satisfies its archive keys');
SELECT results_eq($query$SELECT inherits_archive, archived FROM resources WHERE id = '40000000-0000-7000-8000-000000000005'$query$, $expected$VALUES (TRUE, TRUE)$expected$, 'a folder written below an archived folder inherits its archive');
SET CONSTRAINTS ALL DEFERRED;
SET ROLE app;
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000006', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id, archived_at) VALUES ('40000000-0000-7000-8000-000000000006', 'folder', '20000000-0000-7000-8000-000000000001', now());
SELECT lives_ok('SET CONSTRAINTS ALL IMMEDIATE', 'a folder created archived satisfies its archive keys');
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT archived, parent_archived FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000006'$query$, $expected$VALUES (TRUE, FALSE)$expected$, 'a folder created archived copies its archive onto its edge');

RESET ROLE;
SELECT max(id) AS audit_mark FROM audit_events \gset
SET ROLE app;
UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001';
RESET ROLE;
SELECT results_eq(format($query$SELECT table_name, operation::text, old_row ->> 'id' FROM audit_events WHERE id > %s$query$, :audit_mark), $expected$VALUES ('resources'::text, 'UPDATE'::text, '20000000-0000-7000-8000-000000000001'::text)$expected$, 'organization archive audits only the archived row');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
