-- tests/behaviour/membership_removal.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
-- The new membership reveals the other user after server delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations,users
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000002', 'organization', X'20000000000070008000000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000002', X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO resources (id, kind, organization_id) VALUES
  (X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES (X'20000000000070008000000000000002', X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES
  (X'20000000000070008000000000000002', X'10000000000070008000000000000002', 'active');
INSERT INTO teams (id, organization_id) VALUES
  (X'30000000000070008000000000000004', X'20000000000070008000000000000002'),
  (X'30000000000070008000000000000005', X'20000000000070008000000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  (X'30000000000070008000000000000004', X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'admin');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  (X'20000000000070008000000000000002', X'20000000000070008000000000000002', X'10000000000070008000000000000002', 'user', 'admin');

-- The server removes the departed member's grants.

-- The removed member loses direct admin authority.
-- Removing the grants hides the organization, resources and parent edges after server delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=grants,organizations,resources,resource_parents
DELETE FROM memberships WHERE organization_id = X'20000000000070008000000000000002' AND user_id = X'10000000000070008000000000000001';
