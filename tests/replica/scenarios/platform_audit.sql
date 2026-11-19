-- tests/behaviour/platform_audit.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- Platform audit is hidden from organization admins.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000001', 'organization', '20000000-0000-7000-8000-000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'active');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'user', 'admin');

--! server
INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');

-- The platform operator reads the delivered platform audit.
--! client user=10000000-0000-7000-8000-000000000002 expect=ok

-- Platform audit is hidden from installations acting for an operator.
--! client user=10000000-0000-7000-8000-000000000002 installation=90000000-0000-7000-8000-000000000099 expect=ok
