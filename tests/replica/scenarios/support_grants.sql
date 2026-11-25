-- tests/behaviour/support_grants.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000002', X'20000000000070008000000000000001', 'member2@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000002 email=member2@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active', X'71000000000070008000000000000002');

--! server
INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');

-- A support operator cannot receive a permanent grant. The replica never holds another user's
-- platform_operators row, so only the server refuses the support grants below.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'reader');

-- A support grant rejects an infinite expiry.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'reader', 'infinity');

-- A support grant accepts any finite expiry.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at) VALUES (X'20000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'reader', '2126-01-01 00:00:00.000000+00:00');

-- A support grant's expiry cannot be removed.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
UPDATE grants SET expires_at = NULL WHERE resource_id = X'20000000000070008000000000000001' AND grantee_id = X'10000000000070008000000000000002';
