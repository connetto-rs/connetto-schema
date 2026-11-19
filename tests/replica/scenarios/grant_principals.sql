-- tests/behaviour/grant_principals.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

RESET ROLE;
UPDATE grantees SET id = 'b0000000-0000-7000-8000-000000000001' WHERE kind = 'everyone';

-- The server stamps the founding grant in `organizations`.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- Membership reveals the new co-member in `users` after delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=users
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team', 'admin');

--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', X'0101010101010101010101010101010101010101010101010101010101010101', '10000000-0000-7000-8000-000000000002');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', X'0202020202020202020202020202020202020202020202020202020202020202', '10000000-0000-7000-8000-000000000002');

-- The audience cannot hold admin.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'b0000000-0000-7000-8000-000000000001', 'everyone', 'admin');

-- An empty team cannot replace the last user admin.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
DELETE FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000001';

-- A `team` block is rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team');

-- A `link` block is rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link');

-- A `everyone` block is rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'b0000000-0000-7000-8000-000000000001', 'everyone');

