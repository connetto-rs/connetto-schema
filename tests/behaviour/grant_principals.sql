\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(11);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'writer', '10000000-0000-7000-8000-000000000002');
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', 'team', 'admin');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), 'a0000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000002'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), 'a0000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('02', 32), 'hex'), '10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
RESET ROLE;
SELECT id AS audience_id FROM grantees WHERE kind = 'everyone' \gset
SET ROLE app;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT throws_ok(format($statement$INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES (%L, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), %L, 'bc3cf2e2-768c-4af9-bf86-65f23378a212', %L, %L, %L)$statement$, '40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', :'audience_id', 'everyone', 'admin'), '23514', NULL, 'audience cannot hold admin');

SELECT throws_ok($statement$DELETE FROM user_grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', 'organization 20000000-0000-7000-8000-000000000001 would lose its last admin', 'empty team cannot replace last user admin');

SELECT throws_ok($statement$INSERT INTO installation_blocks (organization_namespace_id, organization_id, installation_namespace_id, installation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'team block is rejected');

SELECT throws_ok($statement$INSERT INTO installation_blocks (organization_namespace_id, organization_id, installation_namespace_id, installation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), 'a0000000-0000-7000-8000-000000000002')$statement$, '42501', NULL, 'link block is rejected');

SELECT throws_ok(format($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), %L, %L)$statement$, '20000000-0000-7000-8000-000000000001', :'audience_id'), '42501', NULL, 'audience block is rejected');

SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', 'organization', 'reader'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'visible grant principal kind must match');
SELECT throws_ok($statement$INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'reader', '10000000-0000-7000-8000-000000000003')$statement$, '42501', NULL, 'hidden grant principal is refused');
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', NULL, 'reader')$statement$, '23502', NULL, 'visible grant principal kind is required');

SELECT throws_ok($statement$INSERT INTO installation_blocks (organization_namespace_id, organization_id, installation_namespace_id, installation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'bc3cf2e2-768c-4af9-bf86-65f23378a212', '10000000-0000-7000-8000-000000000002'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '42501', NULL, 'a user cannot receive an installation block');
SELECT throws_ok($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003')$statement$, '42501', NULL, 'hidden block principal is refused');
SELECT throws_ok($statement$INSERT INTO user_blocks (organization_namespace_id, organization_id, user_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', NULL)$statement$, '42501', NULL, 'a user block requires a visible user');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
