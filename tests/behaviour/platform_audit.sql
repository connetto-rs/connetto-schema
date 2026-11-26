\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT results_eq($query$SELECT table_name, operation::text, actor_id FROM platform_audit_events ORDER BY id$query$, $expected$VALUES ('users'::text, 'INSERT'::text, NULL::uuid), ('namespaces', 'INSERT', NULL), ('users', 'INSERT', NULL), ('namespaces', 'INSERT', NULL), ('organizations', 'INSERT', '10000000-0000-7000-8000-000000000001'::uuid), ('organizations', 'UPDATE', '10000000-0000-7000-8000-000000000001'::uuid)$expected$, 'platform audit records user provisioning and organization founding');

SET ROLE app;
SELECT is_empty($query$SELECT * FROM platform_audit_events$query$, 'platform audit is hidden from organization admins');

RESET ROLE;
INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SET LOCAL ROLE app;
SELECT results_eq($query$SELECT table_name || ' ' || operation FROM platform_audit_events ORDER BY id$query$, $expected$VALUES ('users INSERT'::text), ('namespaces INSERT'), ('users INSERT'), ('namespaces INSERT'), ('organizations INSERT'), ('organizations UPDATE'), ('platform_operators INSERT')$expected$, 'platform operator reads platform audit');

SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000099', true);
SELECT is_empty($query$SELECT * FROM platform_audit_events$query$, 'platform audit is hidden from installations acting for an operator');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
