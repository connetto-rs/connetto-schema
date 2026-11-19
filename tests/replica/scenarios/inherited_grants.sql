-- tests/behaviour/inherited_grants.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
-- Adding the second member reveals that user after delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations,users
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000002', 'organization', '20000000-0000-7000-8000-000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES
  ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'active');
INSERT INTO teams (id, organization_id) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002'),
  ('30000000-0000-7000-8000-000000000005', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'admin');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'user', 'admin');

-- organization grant reaches nested ownable.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO resources (id, kind, organization_id) SELECT '50000000-0000-7000-8000-000000000099', 'project', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000003';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, '50000000-0000-7000-8000-000000000099', 'project', '40000000-0000-7000-8000-000000000003', ancestor.kind FROM resources ancestor WHERE ancestor.id = '40000000-0000-7000-8000-000000000003';
INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES ('60000000-0000-7000-8000-000000000099', '20000000-0000-7000-8000-000000000002', '50000000-0000-7000-8000-000000000099', '10000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-000000000099', 'ownable', '20000000-0000-7000-8000-000000000002');
