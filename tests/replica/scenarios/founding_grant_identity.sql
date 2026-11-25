-- tests/behaviour/founding_grant_identity.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding grant in `organizations`.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000006', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000006', 'organization', X'20000000000070008000000000000006');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000006', X'10000000000070008000000000000001', 'active');

-- Only the founder takes the founding grant.
--! client user=10000000-0000-7000-8000-000000000002 expect=42501
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'20000000000070008000000000000006', X'20000000000070008000000000000006', X'10000000000070008000000000000002', 'user', 'admin');

