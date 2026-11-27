-- tests/behaviour/database_stamped_timestamps.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding grant in `organizations`.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000002', 'organization', X'20000000000070008000000000000002');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000002', X'10000000000070008000000000000001', 'active');
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000003', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000003', 'organization', X'20000000000070008000000000000003');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000003', X'10000000000070008000000000000001', 'active');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind) VALUES (X'20000000000070008000000000000002', X'40000000000070008000000000000003', 'folder', X'20000000000070008000000000000002', 'organization');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES (X'a0000000000070008000000000000003', X'20000000000070008000000000000003', X'0303030303030303030303030303030303030303030303030303030303030303', X'10000000000070008000000000000001');

-- Only the server carries the archive into the copies of the rows below it.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=resources,grants
UPDATE resources SET archived_at = '2000-01-01 00:00:00.000000+00:00' WHERE id = X'40000000000070008000000000000003';

-- The application preserves the stored archive timestamp.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resources SET archived_at = '2000-01-01 00:00:00.000000+00:00' WHERE id = X'40000000000070008000000000000003';

-- Archive restoration keeps `NULL`.
-- Only the server clears the archive from the copies of the rows below it.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=resources,grants
UPDATE resources SET archived_at = NULL WHERE id = X'40000000000070008000000000000003';

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE share_links SET revoked_at = '2000-01-01 00:00:00.000000+00:00' WHERE id = X'a0000000000070008000000000000003';

-- The application preserves the stored revocation timestamp.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE share_links SET revoked_at = '2000-01-01 00:00:00.000000+00:00' WHERE id = X'a0000000000070008000000000000003';

