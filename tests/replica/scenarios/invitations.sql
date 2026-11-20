-- tests/behaviour/invitations.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO resources (id, kind, organization_id) SELECT X'50000000000070008000000000000002', 'project', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = X'20000000000070008000000000000001';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = X'20000000000070008000000000000001';
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000003', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000003', 'organization', X'20000000000070008000000000000003');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000003', X'10000000000070008000000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000003', X'20000000000070008000000000000003', X'10000000000070008000000000000001', 'user', 'admin');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'70000000000070008000000000000001', X'20000000000070008000000000000001', 'b@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- invitee sees invitation.
--! client user=10000000-0000-7000-8000-000000000002 email=b@example.com expect=ok

-- Server marks the invitation accepted.
-- Member sees memberships.
-- Member without a grant cannot see projects.
-- The server marks the invitation accepted after membership insertion.
-- Acceptance reveals the other organization memberships after delivery.
-- Acceptance reveals the other organization users after delivery.
--! client user=10000000-0000-7000-8000-000000000002 email=b@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) SELECT pending.organization_id, X'10000000000070008000000000000002', 'active', X'70000000000070008000000000000001' FROM invitations pending WHERE pending.id = X'70000000000070008000000000000001';

-- invitation acceptance cannot be forged.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id, accepted_by_id) VALUES
    (X'70000000000070008000000000000002', X'20000000000070008000000000000001', 'forged@example.com', '2126-01-01 00:00:00.000000+00:00',
      X'10000000000070008000000000000001', X'10000000000070008000000000000002');

-- accepted invitation stays while its member stays.
--! client user=10000000-0000-7000-8000-000000000001 expect=23503
DELETE FROM invitations WHERE id = X'70000000000070008000000000000001';

-- accepted invitation can be deleted once its member leaves.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
DELETE FROM memberships WHERE organization_id = X'20000000000070008000000000000001' AND user_id = X'10000000000070008000000000000002';
DELETE FROM invitations WHERE id = X'70000000000070008000000000000001';
