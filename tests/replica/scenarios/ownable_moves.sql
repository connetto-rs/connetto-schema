-- tests/behaviour/ownable_moves.sql on both engines.

--! server
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');

-- The server stamps the founding time on the organization.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok diverges=organizations
INSERT INTO organizations (id, created_by_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001');
INSERT INTO resources (id, kind, organization_id) VALUES (X'20000000000070008000000000000001', 'organization', X'20000000000070008000000000000001');
INSERT INTO memberships (organization_id, user_id, state) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000001', 'active');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) VALUES (X'40000000000070008000000000000001', 'folder', X'20000000000070008000000000000001', X'20000000000070008000000000000001', 'organization');
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) SELECT X'40000000000070008000000000000002', 'folder', ancestor.organization_id, X'40000000000070008000000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = X'40000000000070008000000000000001';
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) SELECT X'50000000000070008000000000000001', 'project', ancestor.organization_id, X'40000000000070008000000000000002', ancestor.kind FROM resources ancestor WHERE ancestor.id = X'40000000000070008000000000000002';
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) SELECT X'50000000000070008000000000000002', 'project', ancestor.organization_id, X'20000000000070008000000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = X'20000000000070008000000000000001';
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind, created_by_id) VALUES (X'60000000000070008000000000000001', 'ownable', X'20000000000070008000000000000001', X'50000000000070008000000000000001', 'project', X'10000000000070008000000000000001');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES (X'71000000000070008000000000000002', X'20000000000070008000000000000001', 'member2@example.com', '2126-01-01 00:00:00.000000+00:00', X'10000000000070008000000000000001');

-- The server accepts the invitation and delivers co-member rows.
--! client user=10000000-0000-7000-8000-000000000002 email=member2@example.com expect=ok diverges=invitations,memberships,users
INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES (X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'active', X'71000000000070008000000000000002');

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  (X'40000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'writer'),
  (X'50000000000070008000000000000002', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'writer');
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000002' WHERE id = X'60000000000070008000000000000001';

--! client user=10000000-0000-7000-8000-000000000002 expect=ok

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO resources (id, kind, organization_id, parent_id, parent_kind) SELECT X'50000000000070008000000000000003', 'project', ancestor.organization_id, X'20000000000070008000000000000001', ancestor.kind FROM resources ancestor WHERE ancestor.id = X'20000000000070008000000000000001';

--! client user=10000000-0000-7000-8000-000000000001 expect=ok
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (X'60000000000070008000000000000001', X'20000000000070008000000000000001', X'10000000000070008000000000000002', 'user', 'admin');

-- Moving an ownable requires writer authority on the destination.
--! client user=10000000-0000-7000-8000-000000000002 expect=44000
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000003' WHERE id = X'60000000000070008000000000000001';

-- An admin can move the ownable.
--! client user=10000000-0000-7000-8000-000000000001 expect=ok
UPDATE resource_moves SET parent_id = X'50000000000070008000000000000001' WHERE id = X'60000000000070008000000000000001';
