\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(2);

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
SELECT is((SELECT authz.is_archived('d0000000-0000-7000-8000-000000000021')), true, 'twenty resource levels exclude organization');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
