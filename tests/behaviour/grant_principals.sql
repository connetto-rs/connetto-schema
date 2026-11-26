\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(11);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002'), ('10000000-0000-7000-8000-000000000003');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_team('30000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer'),
  ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team', 'admin');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000002'),
  ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', decode(repeat('02', 32), 'hex'), '10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
RESET ROLE;
SELECT id AS audience_id FROM grantees WHERE kind = 'everyone' \gset
SET ROLE app;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT throws_ok(format('INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (%L, %L, %L, %L, %L)', '40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', :'audience_id', 'everyone', 'admin'), '23514', NULL, 'audience cannot hold admin');

SELECT throws_ok($statement$DELETE FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', 'organization 20000000-0000-7000-8000-000000000001 would lose its last admin', 'empty team cannot replace last user admin');

SELECT throws_ok($statement$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team')$statement$, '23514', NULL, 'team block is rejected');

SELECT throws_ok($statement$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link')$statement$, '23514', NULL, 'link block is rejected');

SELECT throws_ok(format('INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES (%L, %L, %L)', '20000000-0000-7000-8000-000000000001', :'audience_id', 'everyone'), '23514', NULL, 'audience block is rejected');

SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'organization', 'reader'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'visible grant principal kind must match');
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'user', 'reader')$statement$, '42501', NULL, 'hidden grant principal is refused');
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', NULL, 'reader')$statement$, '23502', NULL, 'visible grant principal kind is required');

SELECT throws_ok($statement$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'installation'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'visible block principal kind must match');
SELECT throws_ok($statement$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'user')$statement$, '42501', NULL, 'hidden block principal is refused');
SELECT throws_ok($statement$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', NULL)$statement$, '23502', NULL, 'visible block principal kind is required');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
