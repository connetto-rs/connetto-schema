\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(21);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000003', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', 'organization');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT parent_id, parent_kind::text FROM resources WHERE kind IN ('folder', 'project') AND id = '40000000-0000-7000-8000-000000000001'$query$, $expected$VALUES ('20000000-0000-7000-8000-000000000001'::uuid, 'organization'::text)$expected$, 'top-level folder has organization parent');

RESET ROLE;
SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES ('40000000-0000-7000-8000-000000000099', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23514', NULL, 'folder without parent is rejected');
SET ROLE app;

SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '50000000-0000-7000-8000-000000000002' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '23514', NULL, 'project cannot parent a resource');

SELECT throws_ok($statement$DELETE FROM resource_moves WHERE id = '40000000-0000-7000-8000-000000000002'$statement$, '42501', NULL, 'move view cannot delete a folder');

SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000003'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'resource cannot cross organizations');

SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000002' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '23514', 'resource 40000000-0000-7000-8000-000000000001 would become its own ancestor', 'resource cycle is rejected');

UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000002';
SELECT is((SELECT parent_kind FROM resources WHERE kind IN ('folder', 'project') AND id = '40000000-0000-7000-8000-000000000002'), 'organization', 'folder can move to organization');

RESET ROLE;
SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES ('60000000-0000-7000-8000-00000000000a', 'ownable', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23514', NULL, 'ownable requires parent and creator');
SET ROLE app;

INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES ('40000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin');
SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-00000000000a', 'folder', '40000000-0000-7000-8000-000000000002');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT parent_id FROM resources WHERE kind IN ('folder', 'project') AND id = '40000000-0000-7000-8000-00000000000a' AND parent_id = '40000000-0000-7000-8000-000000000002'$query$, $expected$VALUES ('40000000-0000-7000-8000-000000000002'::uuid)$expected$, 'folder admin creates a child folder');

SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-00000000000b', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization')$statement$, '42501', NULL, 'folder admin cannot create at the organization root');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_namespace_id, organization_id) VALUES ('50000000-0000-7000-8000-000000000063', 'project', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23514', NULL, 'project requires a parent');
SELECT throws_ok($statement$UPDATE resources SET parent_id = '40000000-0000-7000-8000-000000000001', parent_kind = 'folder' WHERE id = '20000000-0000-7000-8000-000000000001'$statement$, '23514', NULL, 'organization cannot have a parent');
SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind, created_by_id) VALUES ('60000000-0000-7000-8000-000000000063', 'ownable', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '10000000-0000-7000-8000-000000000001')$statement$, '23514', NULL, 'ownable requires a project parent');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT throws_ok($statement$UPDATE resources SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'application cannot update a resource parent directly');
SELECT throws_ok($statement$UPDATE resources SET parent_id = '20000000-0000-7000-8000-000000000001', archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'base table cannot combine movement and archive');
SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001', archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '42703', NULL, 'move view exposes no archive column');
SELECT throws_ok($statement$UPDATE resource_moves SET parent_kind = 'organization' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'move view derives parent kind');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, user_id, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'reader');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT is_empty($query$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000002' WHERE id = '40000000-0000-7000-8000-000000000001' RETURNING id$query$, 'destination admin without source admin cannot move a folder');
SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-00000000000a'$statement$, '44000', NULL, 'folder move requires destination administration');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000004', 'project', '40000000-0000-7000-8000-000000000002');
SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '50000000-0000-7000-8000-000000000004'$statement$, '44000', NULL, 'project move requires destination administration');
SELECT results_eq($query$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-00000000000a' WHERE id = '50000000-0000-7000-8000-000000000004' RETURNING parent_id, parent_kind::text$query$, $expected$VALUES ('40000000-0000-7000-8000-00000000000a'::uuid, 'folder'::text)$expected$, 'project move derives its destination kind');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
