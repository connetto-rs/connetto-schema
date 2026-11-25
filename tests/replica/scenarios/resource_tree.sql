-- tests/behaviour/resource_tree.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');

-- A top-level folder has an organization edge.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'40000000000070008000000000000002', 'folder', X'40000000000070008000000000000001', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES (X'40000000000070008000000000000002', 'folder', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000002', 'organization', X'20000000000070008000000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000002', X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000002', X'20000000000070008000000000000001', 'member2@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000002 email=member2@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active', X'71000000000070008000000000000002');

-- A folder without an edge is rejected. The key reaches into edges a policy hides,
-- so only the server refuses it.
--! client user=10000000-0000-7000-8000-000000000001 upload=23503
INSERT INTO resources (id, kind, organization_id) VALUES (X'40000000000070008000000000000099', 'folder', X'20000000000070008000000000000001');

-- A project cannot parent a resource.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
UPDATE resource_parents SET parent_id = X'50000000000070008000000000000002', parent_kind = 'project' WHERE id = X'40000000000070008000000000000001';

-- App cannot delete an edge directly.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
DELETE FROM resource_parents WHERE id = X'40000000000070008000000000000002';

-- A resource cannot cross organizations. The key reaches into resources a policy hides,
-- so only the server refuses it.
--! client user=10000000-0000-7000-8000-000000000001 upload=23503
UPDATE resource_parents SET parent_id = X'20000000000070008000000000000001' WHERE id = X'40000000000070008000000000000003';

-- A resource cycle is rejected.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
UPDATE resource_parents SET parent_id = X'40000000000070008000000000000002', parent_kind = 'folder' WHERE id = X'40000000000070008000000000000001';

-- A folder can move to the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resource_parents SET parent_id = X'20000000000070008000000000000001', parent_kind = 'organization' WHERE id = X'40000000000070008000000000000002';

-- An ownable resource requires its ownable. The key reaches into ownables a policy hides,
-- so only the server refuses it.
--! client user=10000000-0000-7000-8000-000000000001 upload=23503
INSERT INTO resources (id, kind, organization_id) VALUES (X'6000000000007000800000000000000a', 'ownable', X'20000000000070008000000000000001');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'40000000000070008000000000000002', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'admin');

-- A folder admin creates a child folder.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'4000000000007000800000000000000a', 'folder', X'40000000000070008000000000000002', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES (X'4000000000007000800000000000000a', 'folder', X'20000000000070008000000000000001');

-- A folder admin cannot create at the organization root.
--! client user=10000000-0000-7000-8000-000000000002 expect=42501
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'4000000000007000800000000000000b', 'folder', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'4000000000007000800000000000000b', 'folder', X'20000000000070008000000000000001');
