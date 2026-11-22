\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(3);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT new_row ->> 'parent_kind', new_row ->> 'parent_id' FROM audit_events WHERE table_name = 'resource_parents' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000001' ORDER BY id$query$, $expected$VALUES ('organization'::text, '20000000-0000-7000-8000-000000000001'::text)$expected$, 'organization edge audit includes typed parent');

SELECT results_eq($query$SELECT table_name, operation::text, actor_id FROM audit_events ORDER BY id$query$, $expected$VALUES ('resources'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('memberships'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('grants'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('resource_parents'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('resources'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid)$expected$, 'organization audit records ordered changes and their actor');

DELETE FROM resources WHERE id = '40000000-0000-7000-8000-000000000001';
WITH members AS (DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001'),
  roots AS (DELETE FROM resources WHERE organization_id = '20000000-0000-7000-8000-000000000001')
DELETE FROM organizations WHERE id = '20000000-0000-7000-8000-000000000001';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT throws_ok($statement$SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'deleted organization identifier cannot expose retained audit events');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
