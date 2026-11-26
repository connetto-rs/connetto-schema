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
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT throws_ok($statement$DO $body$
  DECLARE
    level INTEGER;
    parent UUID := '20000000-0000-7000-8000-000000000001';
    child UUID;
  BEGIN
    FOR level IN 1..21 LOOP
      child := ('d0000000-0000-7000-8000-' || lpad(level::text, 12, '0'))::uuid;
      PERFORM pg_temp.create_child_resource(child, 'folder', parent);
      parent := child;
    END LOOP;
  END
  $body$$statement$, '23514', 'resource d0000000-0000-7000-8000-000000000021 would exceed depth 20', 'twenty-one resource levels are rejected');

DO $body$
  DECLARE
    level INTEGER;
    parent UUID := '20000000-0000-7000-8000-000000000001';
    child UUID;
  BEGIN
    FOR level IN 1..20 LOOP
      child := ('d0000000-0000-7000-8000-' || lpad(level::text, 12, '0'))::uuid;
      PERFORM pg_temp.create_child_resource(child, CASE WHEN level = 20 THEN 'project'::authz.resource_kind ELSE 'folder'::authz.resource_kind END, parent);
      parent := child;
    END LOOP;
  END
  $body$;
  SELECT pg_temp.create_ownable('d0000000-0000-7000-8000-000000000021', '20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000020', '10000000-0000-7000-8000-000000000001');
  UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT is((SELECT archived FROM resources WHERE id = 'd0000000-0000-7000-8000-000000000021'), true, 'twenty resource levels exclude organization');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
UPDATE resources SET archived_at = NULL WHERE id = '20000000-0000-7000-8000-000000000001';
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
SELECT throws_ok($statement$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000001' WHERE id = 'd0000000-0000-7000-8000-000000000001'$statement$, '23514', NULL, 'moving a folder checks its deepest project descendant');
SELECT results_eq($query$UPDATE resource_moves SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = 'd0000000-0000-7000-8000-000000000002' RETURNING parent_id$query$, $expected$VALUES ('20000000-0000-7000-8000-000000000001'::uuid)$expected$, 'moving a subtree toward the root reduces its depth');
SELECT lives_ok($statement$UPDATE resource_moves SET parent_id = '40000000-0000-7000-8000-000000000001' WHERE id = 'd0000000-0000-7000-8000-000000000002'$statement$, 'ownable leaf does not consume the resource depth budget');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
