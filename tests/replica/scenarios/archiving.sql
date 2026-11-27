-- tests/behaviour/archiving.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding grant in `organizations`.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'40000000000070008000000000000002', 'folder', X'40000000000070008000000000000001', 'folder');
INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000001', 'project', X'40000000000070008000000000000002', 'folder');
INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000001', X'50000000000070008000000000000002', 'project', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, organization_id, parent_id, created_by_id, kind, parent_kind) VALUES (X'60000000000070008000000000000001', X'20000000000070008000000000000001', X'50000000000070008000000000000001', X'10000000000070008000000000000001', 'ownable', 'project');

-- An ownable moves to the destination project.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000002' WHERE id = X'60000000000070008000000000000001';

-- Archived projects cannot enable sharing.
-- Only the server carries the archive into the copies of the rows below it.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=resources,grants
UPDATE resources SET archived_at = '2000-01-01 00:00:00.000000+00:00' WHERE id = X'40000000000070008000000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = X'50000000000070008000000000000001';

-- Restored projects can enable sharing.
-- Only the server clears the archive from the copies of the rows below it.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=resources,grants
UPDATE resources SET archived_at = NULL WHERE id = X'40000000000070008000000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = X'50000000000070008000000000000001';

