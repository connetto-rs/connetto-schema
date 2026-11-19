-- tests/behaviour/organization_founding.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The founder sees the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- The last admin cannot be deleted.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
DELETE FROM grants WHERE grantee_id = '10000000-0000-7000-8000-000000000001';

-- An organization without an admin is refused.
--! client user=10000000-0000-7000-8000-000000000001 expect=23514
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000001');

-- The organization creator must be the caller.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000002');

-- The creator cannot mark the organization founded.
--! client user=10000000-0000-7000-8000-000000000001 expect=42501
INSERT INTO organizations (id, created_by_id, founded_at) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000001', '2126-01-01 00:00:00.000000+00:00');

-- The founding grant marks the organization founded.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000006', 'organization', '20000000-0000-7000-8000-000000000006');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000006', '20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000001', 'user', 'admin');
