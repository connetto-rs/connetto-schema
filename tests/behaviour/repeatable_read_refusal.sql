\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT plan(1);

CREATE ROLE downstream_checker NOLOGIN;
GRANT USAGE ON SCHEMA authz TO downstream_checker;
SET LOCAL ROLE downstream_checker;
SELECT throws_ok('SELECT authz.refuse_repeatable_read()', '25000', 'row-lock checks require read committed or serializable',
  'a role outside the schema refuses repeatable read through the shared check');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
