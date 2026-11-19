-- tests/behaviour/archived_insert.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding grant in `organizations`.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

-- Membership reveals the new co-member in `users` after delivery.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=users
INSERT INTO resources (id, kind, organization_id) VALUES ('50000000-0000-7000-8000-000000000001', 'project', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind) VALUES ('20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', 'project', '20000000-0000-7000-8000-000000000001', 'organization');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('50000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer');

-- A project writer creates an ownable.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok
INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-000000000001', 'ownable', '20000000-0000-7000-8000-000000000001');

-- A project writer cannot create an ownable already archived.
--! client user=10000000-0000-7000-8000-000000000002 expect=42501
INSERT INTO resources (id, kind, organization_id, archived_at) VALUES ('60000000-0000-7000-8000-000000000002', 'ownable', '20000000-0000-7000-8000-000000000001', '2000-01-01 00:00:00.000000+00:00');

