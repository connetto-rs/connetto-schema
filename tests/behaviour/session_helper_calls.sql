\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(2);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, organization_id, parent_id, created_by_id, kind, parent_kind)
SELECT ('60000000-0000-7000-8000-' || lpad(number::text, 12, '0'))::uuid,
  '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001',
  '10000000-0000-7000-8000-000000000001', 'ownable', 'project'
FROM generate_series(1, 400) number;
SET CONSTRAINTS ALL IMMEDIATE;

SET LOCAL track_functions = 'all';
SELECT coalesce(pg_stat_get_xact_function_calls('authz.acting_installation_id()'::regprocedure), 0) AS calls_before \gset
SET ROLE app;
SELECT is((SELECT count(*) FROM resources WHERE kind = 'ownable'), 400::bigint, 'administrator reads every ownable');
RESET ROLE;
SELECT ok(pg_stat_get_xact_function_calls('authz.acting_installation_id()'::regprocedure) - :calls_before < 100,
  'session helper calls stay below the candidate row count');
SELECT * FROM finish();
ROLLBACK;
