-- tests/behaviour/writer_limits.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founding grant stamps the organization on the server.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES (X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES (X'40000000000070008000000000000002', 'folder', X'20000000000070008000000000000001', X'40000000000070008000000000000001', 'folder');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES (X'50000000000070008000000000000001', 'project', X'20000000000070008000000000000001', X'40000000000070008000000000000002', 'folder');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES (X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind, created_by_id) VALUES (X'60000000000070008000000000000001', 'ownable', X'20000000000070008000000000000001', X'50000000000070008000000000000001', 'project', X'10000000000070008000000000000001');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000002', X'20000000000070008000000000000001', 'member2@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000002 email=member2@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active', X'71000000000070008000000000000002');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'40000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'writer');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'50000000000070008000000000000002', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'writer');
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000002' WHERE id = X'60000000000070008000000000000001';

-- A writer cannot enable sharing.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE resources SET writers_can_share = TRUE WHERE id = X'40000000000070008000000000000001';

-- A writer cannot archive.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE resources SET archived_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = X'40000000000070008000000000000001';

-- A writer cannot move an ownable.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000001' WHERE id = X'60000000000070008000000000000001';

-- A writer cannot enable sharing when creating an ownable.
--! client user=10000000-0000-7000-8000-000000000002 expect=42501
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind, created_by_id, writers_can_share) VALUES (X'60000000000070008000000000000002', 'ownable', X'20000000000070008000000000000001', X'50000000000070008000000000000002', 'project', X'10000000000070008000000000000002', TRUE);

-- Only the server carries the archive into the copies of the rows below it.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=resources,grants
UPDATE resources SET archived_at = '2126-01-01 00:00:00.000000+00:00' WHERE id = X'40000000000070008000000000000001';

-- A writer cannot restore.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
UPDATE resources SET archived_at = NULL WHERE id = X'40000000000070008000000000000001';
