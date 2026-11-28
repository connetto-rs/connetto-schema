\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(3);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '40000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

UPDATE resource_moves SET parent_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001';
SELECT results_eq($query$SELECT parent_id FROM resources WHERE kind = 'ownable'$query$, $expected$VALUES ('50000000-0000-7000-8000-000000000002'::uuid)$expected$, 'ownable moves to the destination project');

UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = '50000000-0000-7000-8000-000000000001';
SELECT is_empty($query$SELECT id FROM resources WHERE kind = 'project' AND writers_can_share$query$, 'archived projects cannot enable sharing');

UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = '50000000-0000-7000-8000-000000000001';
SELECT results_eq($query$SELECT id FROM resources WHERE kind = 'project' AND writers_can_share$query$, $expected$VALUES ('50000000-0000-7000-8000-000000000001'::uuid)$expected$, 'restored projects can enable sharing');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
