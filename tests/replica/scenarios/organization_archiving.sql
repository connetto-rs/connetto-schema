-- tests/behaviour/organization_archiving.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id) SELECT '40000000-0000-7000-8000-000000000002', 'folder', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000001';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, '40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000001';
INSERT INTO resources (id, kind, organization_id) SELECT '50000000-0000-7000-8000-000000000001', 'project', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000002';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, '50000000-0000-7000-8000-000000000001', 'project', '40000000-0000-7000-8000-000000000002', ancestor.kind FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000002';
INSERT INTO resources (id, kind, organization_id) SELECT '50000000-0000-7000-8000-000000000002', 'project', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = '20000000-0000-7000-8000-000000000001';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, '50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = '20000000-0000-7000-8000-000000000001';
INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-000000000001', 'ownable', '20000000-0000-7000-8000-000000000001');

-- The organization archive reaches the nested ownable.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resources SET archived_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = '20000000-0000-7000-8000-000000000001';

-- The organization archive blocks ownable writes.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001';

--! server
UPDATE resources SET archived_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = '40000000-0000-7000-8000-000000000001';

-- A restore under an archived organization changes no rows.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';
