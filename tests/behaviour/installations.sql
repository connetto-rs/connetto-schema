\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(7);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002');
INSERT INTO resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind) VALUES ('40000000-0000-7000-8000-000000000003', 'folder', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000004', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000005', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000004', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'admin');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'organization', 'admin');
INSERT INTO invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id) VALUES
  ('70000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002', 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, true);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', true);

SELECT is_empty($query$SELECT 1 FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'$query$, 'installation cannot read another organization');

SELECT is_empty($query$SELECT 1 FROM authz.member_organizations() WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '20000000-0000-7000-8000-000000000002'$query$, 'membership helper stays in installation organization');

SELECT is_empty($query$SELECT 1 FROM authz.administered_teams() WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000004'$query$, 'team administration stays in installation organization');

SELECT is_empty($query$SELECT 1 FROM grantees WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id IN ('20000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000004')$query$, 'grantees stay in installation organization');

SELECT is_empty($query$UPDATE resources SET writers_can_share = TRUE WHERE id = '40000000-0000-7000-8000-000000000003' RETURNING *$query$, 'installation cannot write another organization');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', 'b@example.com', true);
SELECT results_eq($query$SELECT organization_namespace_id, organization_id FROM authz.pending_invitations()$query$,
  $values$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000002'::UUID)$values$, 'an invitee holds its pending invitation');
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, true);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', true);
SELECT is_empty($query$SELECT 1 FROM authz.pending_invitations()$query$,
  'an installation acting for an invitee holds no pending invitation outside its organizations');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
