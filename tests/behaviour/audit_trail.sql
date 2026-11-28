\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(8);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT new_row ->> 'parent_kind', new_row ->> 'parent_id' FROM audit_events WHERE table_name = 'resources' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000001' ORDER BY id$query$, $expected$VALUES ('organization'::text, '20000000-0000-7000-8000-000000000001'::text)$expected$, 'resource audit includes typed parent');

SELECT results_eq($query$SELECT table_name, operation::text, actor_id FROM audit_events ORDER BY id$query$, $expected$VALUES ('resources'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('memberships'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('user_grants'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid), ('resources'::text, 'INSERT'::text, '10000000-0000-7000-8000-000000000001'::uuid)$expected$, 'organization audit records ordered changes and their actor');

SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT max(id) AS move_audit_mark FROM audit_events \gset
UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000002' WHERE id = '40000000-0000-7000-8000-000000000001';
SELECT results_eq(format($query$SELECT table_name, operation::text, old_row ->> 'parent_id', new_row ->> 'parent_id' FROM audit_events WHERE id > %s ORDER BY id$query$, :move_audit_mark), $expected$VALUES ('resources'::text, 'UPDATE'::text, '20000000-0000-7000-8000-000000000001'::text, '40000000-0000-7000-8000-000000000002'::text)$expected$, 'resource move writes one entity audit row');
UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000001';
DELETE FROM resources WHERE id = '40000000-0000-7000-8000-000000000002';
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT max(id) AS team_audit_mark FROM audit_events \gset
SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001');
UPDATE teams SET parent_namespace_id = NULL, parent_id = NULL WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000002';
SELECT results_eq(format($query$SELECT table_name, operation::text, new_row ->> 'parent_namespace_id', new_row ->> 'parent_id' FROM audit_events WHERE id > %s ORDER BY id$query$, :team_audit_mark), $expected$VALUES ('teams'::text, 'INSERT'::text, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, '30000000-0000-7000-8000-000000000001'::text), ('teams'::text, 'UPDATE'::text, NULL::text, NULL::text)$expected$, 'team insertion and movement each write one entity audit row');
DELETE FROM teams WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id IN ('30000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000002');

DELETE FROM resources WHERE id = '40000000-0000-7000-8000-000000000001';
WITH members AS (DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000001'),
  roots AS (DELETE FROM resources WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000001')
DELETE FROM organizations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000001';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT throws_ok($statement$SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'deleted organization identifier cannot expose retained audit events');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT throws_ok($statement$SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'another user cannot found in the deleted organization''s namespace');
SELECT lives_ok($statement$SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000001'); SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'an equal local id in another namespace founds another organization');
SELECT is_empty(format($query$SELECT id FROM audit_events WHERE organization_namespace_id = %L$query$, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')), 'an organization sharing a local id reads no audit event of the deleted one');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
