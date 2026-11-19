-- tests/behaviour/share_links.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- Membership reveals the new co-member user after server delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=users
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer');

--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', X'0101010101010101010101010101010101010101010101010101010101010101', '10000000-0000-7000-8000-000000000002'),
  ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', X'0202020202020202020202020202020202020202020202020202020202020202', '10000000-0000-7000-8000-000000000002');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE share_links SET revoked_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = 'a0000000-0000-7000-8000-000000000001';

-- A creator cannot undo admin revocation.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE share_links SET revoked_at = NULL WHERE id = 'a0000000-0000-7000-8000-000000000001';

-- A link cannot hold admin.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link', 'admin');

-- An admin can delete a share link.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
DELETE FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002';
