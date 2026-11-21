\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(5);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
SELECT pg_temp.add_member('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer');
INSERT INTO apps (id, organization_id, name) VALUES ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'reader app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES ('80000000-0000-7000-8000-000000000001', '70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'reader');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000002'),
  ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', decode(repeat('02', 32), 'hex'), '10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
UPDATE share_links SET revoked_at = now() WHERE id = 'a0000000-0000-7000-8000-000000000001';
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

SELECT is_empty($query$UPDATE share_links SET revoked_at = NULL WHERE id = 'a0000000-0000-7000-8000-000000000001' RETURNING *$query$, 'creator cannot undo admin revocation');

SELECT set_config('app.installation_id', '80000000-0000-7000-8000-000000000001', false);
SELECT is_empty($query$UPDATE share_links SET revoked_at = now() WHERE id = 'a0000000-0000-7000-8000-000000000002' RETURNING *$query$, 'reader installation cannot revoke creator link');
SELECT throws_ok($statement$INSERT INTO share_links (id, organization_id, token_hash, created_by_id, expires_at) VALUES ('a0000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000002', 'infinity')$statement$, '42501', NULL, 'reader installation cannot create link');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link', 'admin')$statement$, '23514', NULL, 'link cannot hold admin');

DELETE FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002';
SELECT is_empty($query$SELECT 1 FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002'$query$, 'admin can delete share link');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
