\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', '10000000-0000-7000-8000-000000000002')$statement$, '23514', 'support grants require a finite expiry', 'support operator cannot receive a permanent grant');

SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, expires_at, user_id) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', 'infinity', '10000000-0000-7000-8000-000000000002')$statement$, '23514', 'support grants require a finite expiry', 'support grant rejects infinite expiry');

INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, expires_at, user_id) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', now() + interval '100 years', '10000000-0000-7000-8000-000000000002');
SELECT is((SELECT expires_at FROM user_grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002'), now() + interval '100 years', 'support grant accepts any finite expiry');

SELECT throws_ok($statement$UPDATE user_grants SET expires_at = NULL WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002'$statement$, '23514', 'support grants require a finite expiry', 'support grant expiry cannot be removed');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
