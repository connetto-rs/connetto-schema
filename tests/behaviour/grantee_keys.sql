\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(12);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'key app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SET CONSTRAINTS ALL DEFERRED;

-- A subtype row never outlives its grantee row past one statement, even inside a transaction deferring every constraint.
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '10000000-0000-7000-8000-000000000001'$statement$, '23503', NULL, 'a user keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '20000000-0000-7000-8000-000000000001'$statement$, '23503', NULL, 'an organization keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '30000000-0000-7000-8000-000000000001'$statement$, '23503', NULL, 'a team keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = '90000000-0000-7000-8000-000000000001'$statement$, '23503', NULL, 'an installation keeps its grantee row');
SELECT throws_ok($statement$DELETE FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000001'$statement$, '23503', NULL, 'a share link keeps its grantee row');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- The grantee row a BEFORE INSERT trigger writes for a row the insert then skips cannot commit.
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001') ON CONFLICT (token_hash) DO NOTHING; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', NULL, 'a share link skipped on its token leaves no grantee row');
SELECT lives_ok($statement$INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES ('a0000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000001'); DELETE FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'a share link created and deleted in one transaction commits');
RESET ROLE;

-- A grantee subtype keeps its key, so no role can leave a grantee row behind by moving the row.
SET ROLE authz_writer;
SELECT throws_ok($statement$UPDATE public.users SET id = '10000000-0000-7000-8000-000000000009' WHERE id = '10000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'a user key cannot change');
SELECT throws_ok($statement$UPDATE public.organizations SET id = '20000000-0000-7000-8000-000000000009' WHERE id = '20000000-0000-7000-8000-000000000001'$statement$, '42501', NULL, 'an organization key cannot change');
RESET ROLE;

-- The owner can still move a row onto a key a skipped insert left behind, and the grantee row of the old key goes with it.
SELECT lives_ok($statement$INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES ('a0000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001') ON CONFLICT (token_hash) DO NOTHING; UPDATE share_links SET id = 'a0000000-0000-7000-8000-000000000004' WHERE id = 'a0000000-0000-7000-8000-000000000001'; SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED$statement$, 'a share link moves onto a stray grantee key');
SELECT is((SELECT count(*) FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000001'), 0::bigint, 'a moved share link leaves no grantee row under its old key');
SELECT throws_ok($statement$UPDATE grantees SET kind = 'user' WHERE kind = 'everyone'; SET CONSTRAINTS ALL IMMEDIATE$statement$, '23514', NULL, 'a grantee row changed into a user key without its user cannot commit');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
