\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(15);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'key app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- A subtype row never commits without its grantee row.
SELECT throws_ok($statement$INSERT INTO grantees (namespace_id, id, kind) VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212', '10000000-0000-7000-8000-000000000001', 'user')$statement$, '23514', NULL, 'a user cannot be a grantee');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '20000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'an organization keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '30000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'a team keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '90000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'an installation keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23503', NULL, 'a share link keeps its grantee row');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- The grantee row is written after the insert, so a row the insert skips writes none.
SET ROLE app;
SELECT lives_ok($statement$INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001') ON CONFLICT (token_hash) DO NOTHING; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'a share link skipped on its token commits');
RESET ROLE;
SELECT is((SELECT count(*) FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000002'), 0::bigint, 'a share link skipped on its token leaves no grantee row');
SET ROLE app;
SELECT lives_ok($statement$INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000001'); DELETE FROM share_links WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = 'a0000000-0000-7000-8000-000000000003'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'a share link created and deleted in one transaction commits');
RESET ROLE;

-- A grantee subtype keeps its key, so no role can leave a grantee row behind by moving the row.
SET ROLE identity_writer;
SELECT throws_ok($statement$UPDATE public.users SET id = '10000000-0000-7000-8000-000000000009' WHERE id = '10000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'a user key cannot change');
RESET ROLE;
SET ROLE authz_writer;
SELECT throws_ok($statement$UPDATE public.organizations SET id = '20000000-0000-7000-8000-000000000009' WHERE id = '20000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'an organization key cannot change');
RESET ROLE;

-- The owner can still move a row to another key, and the grantee row of the old key goes with it.
SELECT lives_ok($statement$UPDATE share_links SET id = 'a0000000-0000-7000-8000-000000000004' WHERE id = 'a0000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'a share link moves onto another key');
SELECT is((SELECT count(*) FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000001'), 0::bigint, 'a moved share link leaves no grantee row under its old key');
SELECT throws_ok($statement$UPDATE grantees SET kind = 'user' WHERE kind = 'everyone'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', NULL, 'a grantee cannot change into a user');

-- A subtype's kind is derived from its table.
SELECT throws_ok($statement$UPDATE organizations SET kind = 'organization'$statement$, '428C9', NULL, 'an organization kind is never rewritten');
SELECT throws_ok($statement$UPDATE app_installations SET kind = 'installation'$statement$, '428C9', NULL, 'an installation kind is never rewritten');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
