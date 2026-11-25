-- tests/behaviour/membership_removal.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000002', 'organization', X'20000000000070008000000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000002', X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES (X'20000000000070008000000000000002', X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES
  (X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000002', X'20000000000070008000000000000002', 'member2@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000002 email=member2@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000002', 'active', X'71000000000070008000000000000002');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO teams (id, organization_id) VALUES
  (X'30000000000070008000000000000004', X'20000000000070008000000000000002'),
  (X'30000000000070008000000000000005', X'20000000000070008000000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  (X'30000000000070008000000000000004', X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'admin');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  (X'20000000000070008000000000000002', X'20000000000070008000000000000002', X'10000000000070008000000000000002', 'user', 'admin');

-- The server removes the departed member's grants.

-- The removed member loses direct admin authority.
-- Server-side grant removal hides the organization and its member-visible rows.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=grants,organizations,resources,resource_parents,invitations,memberships,teams,team_members
DELETE FROM memberships WHERE organization_id = X'20000000000070008000000000000002' AND user_id = X'10000000000070008000000000000001';

--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000001', X'20000000000070008000000000000002', 'member1@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000002');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000001 email=member1@example.com expect=ok diverges=invitations,memberships,users,teams
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active', X'71000000000070008000000000000001');

--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE memberships SET state = 'deactivated' WHERE organization_id = X'20000000000070008000000000000002' AND user_id = X'10000000000070008000000000000001';
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'90000000000070008000000000000001', X'20000000000070008000000000000002', 'member@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000002');

-- A deactivated member cannot delete its membership.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
DELETE FROM memberships WHERE organization_id = X'20000000000070008000000000000002' AND user_id = X'10000000000070008000000000000001';

-- A pending invitation cannot reactivate a deactivated member.
--! client user=10000000-0000-7000-8000-000000000001 email=member@example.com expect=23505
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active', X'90000000000070008000000000000001');
