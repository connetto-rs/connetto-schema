-- tests/behaviour/resource_depth.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- Twenty-one resource levels are rejected.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000002', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000002', 'folder', 'd0000000-0000-7000-8000-000000000001', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000003', 'folder', 'd0000000-0000-7000-8000-000000000002', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000004', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000004', 'folder', 'd0000000-0000-7000-8000-000000000003', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000005', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000005', 'folder', 'd0000000-0000-7000-8000-000000000004', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000006', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000006', 'folder', 'd0000000-0000-7000-8000-000000000005', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000007', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000007', 'folder', 'd0000000-0000-7000-8000-000000000006', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000008', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000008', 'folder', 'd0000000-0000-7000-8000-000000000007', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000009', 'folder', 'd0000000-0000-7000-8000-000000000008', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000010', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000010', 'folder', 'd0000000-0000-7000-8000-000000000009', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000011', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000011', 'folder', 'd0000000-0000-7000-8000-000000000010', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000012', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000012', 'folder', 'd0000000-0000-7000-8000-000000000011', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000013', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000013', 'folder', 'd0000000-0000-7000-8000-000000000012', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000014', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000014', 'folder', 'd0000000-0000-7000-8000-000000000013', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000015', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000015', 'folder', 'd0000000-0000-7000-8000-000000000014', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000016', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000016', 'folder', 'd0000000-0000-7000-8000-000000000015', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000017', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000017', 'folder', 'd0000000-0000-7000-8000-000000000016', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000018', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000018', 'folder', 'd0000000-0000-7000-8000-000000000017', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000019', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000019', 'folder', 'd0000000-0000-7000-8000-000000000018', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000020', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000020', 'folder', 'd0000000-0000-7000-8000-000000000019', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000021', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000021', 'folder', 'd0000000-0000-7000-8000-000000000020', 'folder');

-- Twenty resource levels exclude the organization when inheriting its archive.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000002', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000002', 'folder', 'd0000000-0000-7000-8000-000000000001', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000003', 'folder', 'd0000000-0000-7000-8000-000000000002', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000004', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000004', 'folder', 'd0000000-0000-7000-8000-000000000003', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000005', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000005', 'folder', 'd0000000-0000-7000-8000-000000000004', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000006', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000006', 'folder', 'd0000000-0000-7000-8000-000000000005', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000007', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000007', 'folder', 'd0000000-0000-7000-8000-000000000006', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000008', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000008', 'folder', 'd0000000-0000-7000-8000-000000000007', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000009', 'folder', 'd0000000-0000-7000-8000-000000000008', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000010', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000010', 'folder', 'd0000000-0000-7000-8000-000000000009', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000011', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000011', 'folder', 'd0000000-0000-7000-8000-000000000010', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000012', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000012', 'folder', 'd0000000-0000-7000-8000-000000000011', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000013', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000013', 'folder', 'd0000000-0000-7000-8000-000000000012', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000014', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000014', 'folder', 'd0000000-0000-7000-8000-000000000013', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000015', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000015', 'folder', 'd0000000-0000-7000-8000-000000000014', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000016', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000016', 'folder', 'd0000000-0000-7000-8000-000000000015', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000017', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000017', 'folder', 'd0000000-0000-7000-8000-000000000016', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000018', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000018', 'folder', 'd0000000-0000-7000-8000-000000000017', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000019', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000019', 'folder', 'd0000000-0000-7000-8000-000000000018', 'folder');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000020', 'project', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000020', 'project', 'd0000000-0000-7000-8000-000000000019', 'folder');
INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES ('d0000000-0000-7000-8000-000000000021', '20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000020', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('d0000000-0000-7000-8000-000000000021', 'ownable', '20000000-0000-7000-8000-000000000001');
UPDATE resources SET archived_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = '20000000-0000-7000-8000-000000000001';
