-- tests/behaviour/resource_tree.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- A top-level folder has an organization edge.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000002', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001', 'organization');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000002', 'organization', '20000000-0000-7000-8000-000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- Membership reveals the new co-member user after server delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=users
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active');

-- A folder without an edge is rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000099', 'folder', '20000000-0000-7000-8000-000000000001');

-- A project cannot parent a resource.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
UPDATE resource_parents SET parent_id = '50000000-0000-7000-8000-000000000002', parent_kind = 'project' WHERE id = '40000000-0000-7000-8000-000000000001';

-- A required edge cannot be removed.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
DELETE FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000002';

-- A resource cannot cross organizations. The key reaches into resources a policy hides,
-- so only the server refuses it.
--! client user=10000000-0000-7000-8000-000000000001 upload=23503
UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000003';

-- A resource cycle is rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
UPDATE resource_parents SET parent_id = '40000000-0000-7000-8000-000000000002', parent_kind = 'folder' WHERE id = '40000000-0000-7000-8000-000000000001';

-- A folder can move to the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001', parent_kind = 'organization' WHERE id = '40000000-0000-7000-8000-000000000002';

-- An ownable resource requires its ownable.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-00000000000a', 'ownable', '20000000-0000-7000-8000-000000000001');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');

-- A folder admin creates a child folder.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-00000000000a', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-00000000000a', 'folder', '40000000-0000-7000-8000-000000000002', 'folder');

-- A folder admin cannot create at the organization root.
--! client user=10000000-0000-7000-8000-000000000002 expect=42501
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-00000000000b', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-00000000000b', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
