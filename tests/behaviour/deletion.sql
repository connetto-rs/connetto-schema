\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(2);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000003', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', 'organization');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000003');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000005', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000005', 'team', 'reader');
INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000003', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

DELETE FROM teams WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000005';
SELECT is_empty($query$SELECT namespace_id, id FROM teams WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000005' UNION ALL SELECT grantee_namespace_id, grantee_id FROM grants WHERE grantee_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND grantee_id = '30000000-0000-7000-8000-000000000005'$query$, 'team deletion cascades cross-organization grants');

RESET ROLE;
DELETE FROM share_links WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM user_grants WHERE resource_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM memberships WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM resources WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM organizations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000003';
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT 'organization'::text FROM organizations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000003' UNION ALL SELECT 'link' FROM share_links WHERE organization_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND organization_id = '20000000-0000-7000-8000-000000000003' UNION ALL SELECT 'grantee' FROM grantees WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = 'a0000000-0000-7000-8000-000000000003' UNION ALL SELECT 'audit' FROM platform_audit_events WHERE table_name = 'organizations' AND operation = 'DELETE' AND old_row ->> 'namespace_id' = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text AND old_row ->> 'id' = '20000000-0000-7000-8000-000000000003'$query$, $expected$VALUES ('audit'::text)$expected$, 'organization deletion after link and dependent cleanup');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
