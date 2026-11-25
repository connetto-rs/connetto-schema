\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(7);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002'),
  ('10000000-0000-7000-8000-000000000003'), ('10000000-0000-7000-8000-000000000004'), ('10000000-0000-7000-8000-000000000005');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
INSERT INTO grants (organization_id, resource_id, grantee_id, grantee_kind, role) VALUES
  ('20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002', (SELECT id FROM grantees WHERE kind = 'signed_in'), 'signed_in', 'reader');
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES
  ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001'),
  ('70000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
RESET ROLE;
UPDATE invitations SET expires_at = now() - interval '1 day' WHERE id = '70000000-0000-7000-8000-000000000002';

SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', 'b@example.com', false);
SET ROLE app;
SELECT results_eq($query$SELECT id FROM organizations$query$, $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID)$values$, 'a pending invitee reads the inviting organization');
SELECT pg_temp.accept_invitation('70000000-0000-7000-8000-000000000001');
SELECT results_eq($query$SELECT id FROM organizations$query$, $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID)$values$, 'a member without an organization grant reads its organization');
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT set_config('app.verified_email', 'c@example.com', false);
SET ROLE app;
SELECT results_eq($query$SELECT id FROM organizations$query$, $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID)$values$, 'a reader of a shared project reads its organization');
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000004');
SELECT set_config('app.verified_email', 'd@example.com', false);
SET ROLE app;
INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000004', '10000000-0000-7000-8000-000000000004');
SELECT results_eq($query$SELECT id FROM organizations WHERE id = '20000000-0000-7000-8000-000000000004'$query$, $values$VALUES ('20000000-0000-7000-8000-000000000004'::UUID)$values$, 'a founder reads the organization it is founding');
INSERT INTO resources (id, kind, organization_id) VALUES ('20000000-0000-7000-8000-000000000004', 'organization', '20000000-0000-7000-8000-000000000004');
SELECT results_eq($query$SELECT id FROM resources WHERE id = '20000000-0000-7000-8000-000000000004'$query$, $values$VALUES ('20000000-0000-7000-8000-000000000004'::UUID)$values$, 'a founder reads the organization resource its founding grant points at');
RESET ROLE;

DELETE FROM grants WHERE grantee_kind = 'signed_in';
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SELECT set_config('app.verified_email', 'c@example.com', false);
SET ROLE app;
SELECT is_empty($query$SELECT id FROM organizations$query$, 'an expired invitation reveals no organization');
RESET ROLE;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000005');
SELECT set_config('app.verified_email', 'e@example.com', false);
SET ROLE app;
SELECT is_empty($query$SELECT id FROM organizations$query$, 'an unrelated user reads no organization');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
