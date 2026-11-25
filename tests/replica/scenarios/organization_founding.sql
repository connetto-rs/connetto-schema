-- tests/behaviour/organization_founding.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founder sees the organization. The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');

-- The last admin cannot be deleted.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
DELETE FROM grants WHERE grantee_id = X'10000000000070008000000000000001';

-- An organization without an admin is refused.
--! client user=10000000-0000-7000-8000-000000000001 upload=23514
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000005', X'10000000000070008000000000000001');

-- The organization creator must be the caller.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000005', X'10000000000070008000000000000002');

-- The creator cannot mark the organization founded.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO organizations (id, created_by_id, founded_at) VALUES (X'20000000000070008000000000000005', X'10000000000070008000000000000001', '2126-01-01 00:00:00.000000+00:00');

-- The founding grant marks the organization founded. The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000006', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000006', 'organization', X'20000000000070008000000000000006');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000006', X'10000000000070008000000000000001', 'active');

--! server
WITH members AS (DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001'),
  roots AS (DELETE FROM resources WHERE organization_id = '20000000-0000-7000-8000-000000000001')
DELETE FROM organizations WHERE id = '20000000-0000-7000-8000-000000000001';

-- Retained audit events retire the identifier at upload.
--! client user=10000000-0000-7000-8000-000000000002 upload=23505
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active');
