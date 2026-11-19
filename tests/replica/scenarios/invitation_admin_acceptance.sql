-- tests/behaviour/invitation_admin_acceptance.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
INSERT INTO resources (id, kind, organization_id) SELECT '50000000-0000-7000-8000-000000000002', 'project', ancestor.organization_id FROM resources ancestor WHERE ancestor.id = '20000000-0000-7000-8000-000000000001';
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) SELECT ancestor.organization_id, '50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = '20000000-0000-7000-8000-000000000001';
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000003', 'organization', '20000000-0000-7000-8000-000000000003');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'b@example.com', '2126-01-01 00:00:00.000000+00:00', '10000000-0000-7000-8000-000000000001');

-- The server marks the invitation accepted after membership insertion.
-- Acceptance reveals the other organization memberships after delivery.
-- Acceptance reveals the other organization users after delivery.
--! client user=10000000-0000-7000-8000-000000000002 email=b@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) SELECT pending.organization_id, '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000001' FROM invitations pending WHERE pending.id = '70000000-0000-7000-8000-000000000001';

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', '2126-01-01 00:00:00.000000+00:00', '10000000-0000-7000-8000-000000000001');
DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';

-- admin cannot accept an invitation for a member.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000003');
