\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
SELECT plan(1);

SELECT is_empty($query$
  WITH targets AS (
    SELECT function.oid AS function_id, 0::oid AS relation_id
    FROM pg_proc function
    JOIN pg_language language ON language.oid = function.prolang AND language.lanname = 'plpgsql'
    JOIN pg_namespace namespace ON namespace.oid = function.pronamespace
    WHERE namespace.nspname NOT IN ('pg_catalog', 'information_schema', 'test_tools')
      AND function.prorettype <> 'trigger'::regtype
    UNION ALL
    SELECT trigger.tgfoid, trigger.tgrelid
    FROM pg_trigger trigger
    JOIN pg_proc function ON function.oid = trigger.tgfoid
    JOIN pg_language language ON language.oid = function.prolang AND language.lanname = 'plpgsql'
    WHERE NOT trigger.tgisinternal
  )
  SELECT targets.function_id::regprocedure, targets.relation_id::regclass, finding.lineno, finding.level, finding.message
  FROM targets,
    LATERAL plpgsql_check_function_tb(
      targets.function_id,
      targets.relation_id,
      performance_warnings => true,
      extra_warnings => true,
      security_warnings => true
    ) finding
$query$, 'plpgsql_check reports nothing on any PL/pgSQL function or trigger');

SELECT * FROM finish();
ROLLBACK;
