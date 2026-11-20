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
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SET LOCAL ROLE app;
SELECT results_eq($query$SELECT id FROM platform_operators$query$, $expected$VALUES ('10000000-0000-7000-8000-000000000002'::uuid)$expected$, 'platform operator reads their own operator row');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT is_empty($query$SELECT * FROM platform_operators$query$, 'platform operator rows are hidden from other users');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000099', true);
SELECT is_empty($query$SELECT * FROM platform_operators$query$, 'platform operator rows are hidden from installations acting for an operator');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
