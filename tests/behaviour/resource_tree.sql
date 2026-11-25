\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(10);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT parent_id, parent_kind::text FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000001'$query$, $expected$VALUES ('20000000-0000-7000-8000-000000000001'::uuid, 'organization'::text)$expected$, 'top-level folder has organization edge');

SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000099', 'folder', '20000000-0000-7000-8000-000000000001')$statement$, '23503', NULL, 'folder without edge is rejected');

SELECT throws_ok($statement$UPDATE resource_parents SET parent_id = '50000000-0000-7000-8000-000000000002', parent_kind = 'project' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '23514', NULL, 'project cannot parent a resource');

SELECT throws_ok($statement$DELETE FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000002'$statement$, '42501', NULL, 'app cannot delete an edge directly');

SELECT throws_ok($statement$UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000003'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'resource cannot cross organizations');

SELECT throws_ok($statement$UPDATE resource_parents SET parent_id = '40000000-0000-7000-8000-000000000002', parent_kind = 'folder' WHERE id = '40000000-0000-7000-8000-000000000001'$statement$, '23514', 'resource 40000000-0000-7000-8000-000000000001 would become its own ancestor', 'resource cycle is rejected');

UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001', parent_kind = 'organization' WHERE id = '40000000-0000-7000-8000-000000000002';
SELECT is((SELECT parent_kind FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000002'), 'organization', 'folder can move to organization');

SELECT throws_ok($statement$INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-00000000000a', 'ownable', '20000000-0000-7000-8000-000000000001')$statement$, '23503', NULL, 'ownable resource requires its ownable');

INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-00000000000a', 'folder', '40000000-0000-7000-8000-000000000002');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT parent_id FROM resource_parents WHERE id = '40000000-0000-7000-8000-00000000000a' AND parent_id = '40000000-0000-7000-8000-000000000002'$query$, $expected$VALUES ('40000000-0000-7000-8000-000000000002'::uuid)$expected$, 'folder admin creates a child folder');

SELECT throws_ok($statement$INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
      VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-00000000000b', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-00000000000b', 'folder', '20000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'folder admin cannot create at the organization root');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
