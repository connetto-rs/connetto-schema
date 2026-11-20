-- tests/behaviour/resource_deletion.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002'), ('10000000-0000-7000-8000-000000000003');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'user', 'admin');

-- Memberships reveal the new co-member users after server delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=users
INSERT INTO resources (id, kind, organization_id) VALUES (X'50000000000070008000000000000001', 'project', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000001', 'project', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES (X'50000000000070008000000000000003', 'project', X'20000000000070008000000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000003', 'project', X'40000000000070008000000000000001', 'folder');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000003', 'active');
INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES (X'60000000000070008000000000000001', X'20000000000070008000000000000001', X'50000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'60000000000070008000000000000001', 'ownable', X'20000000000070008000000000000001');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'60000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'admin');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'60000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000003', 'user', 'reader');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'50000000000070008000000000000002', X'20000000000070008000000000000001', X'10000000000070008000000000000003', 'user', 'reader');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'50000000000070008000000000000003', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'admin');

-- A direct admin deletes an ownable and the server removes its resource and grants.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok diverges=resources,grants
DELETE FROM ownables WHERE id = X'60000000000070008000000000000001';

-- An organization admin deletes a project with its edge and grants.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
DELETE FROM resources WHERE id = X'50000000000070008000000000000002';

-- A folder with a child cannot be deleted.
--! client user=10000000-0000-7000-8000-000000000001 expect=23503
DELETE FROM resources WHERE id = X'40000000000070008000000000000001';

-- A project admin without organization admin cannot delete the project.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
DELETE FROM resources WHERE id = X'50000000000070008000000000000003';
