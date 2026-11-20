-- tests/behaviour/idempotent_inserts.sql on both engines.

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
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (id, organization_id) SELECT '30000000-0000-7000-8000-000000000002', ancestor.organization_id FROM teams ancestor WHERE ancestor.id = '30000000-0000-7000-8000-000000000001';
INSERT INTO team_parents (organization_id, id, parent_id) SELECT ancestor.organization_id, '30000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000001' FROM teams ancestor WHERE ancestor.id = '30000000-0000-7000-8000-000000000001';
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
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer'),
  ('50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer');
UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001';
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'admin');

--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', X'0101010101010101010101010101010101010101010101010101010101010101', '10000000-0000-7000-8000-000000000002'),
  ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', X'0202020202020202020202020202020202020202020202020202020202020202', '10000000-0000-7000-8000-000000000002');

-- team insert is idempotent. A client cannot UPSERT a row-secured table, which the replica
-- serves as a view, so the client inserts only a key it does not hold.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO teams (id, organization_id) SELECT '30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001'
    WHERE NOT EXISTS (SELECT 1 FROM teams WHERE id = '30000000-0000-7000-8000-000000000001');

-- installation insert is idempotent.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO app_installations (id, app_id, organization_id) SELECT '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001'
    WHERE NOT EXISTS (SELECT 1 FROM app_installations WHERE id = '90000000-0000-7000-8000-000000000001');

-- ownable insert is idempotent.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO ownables (id, organization_id, project_id, created_by_id) SELECT '60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001'
    WHERE NOT EXISTS (SELECT 1 FROM ownables WHERE id = '60000000-0000-7000-8000-000000000001');

-- user insert is idempotent.
--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001') ON CONFLICT (id) DO NOTHING;

-- link insert is idempotent.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO share_links (id, organization_id, token_hash, created_by_id)
    SELECT 'a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', X'0202020202020202020202020202020202020202020202020202020202020202', '10000000-0000-7000-8000-000000000002'
    WHERE NOT EXISTS (SELECT 1 FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002');
