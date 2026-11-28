\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

-- User 1 founds organization 1, joins team 1 and holds share link 1 there. Installation 1 holds
-- only a folder permission in organization 1, installation 2 an organization permission.
SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'member');
INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000002', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_namespace_id, installation_id, organization_namespace_id, organization_id, kind, max_role) VALUES
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'organization', 'reader');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('app.link_ids', jsonb_build_array(jsonb_build_object('namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'id', 'a0000000-0000-7000-8000-000000000001'))::text, false);

SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, true);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000002', false);
SELECT results_eq($query$SELECT namespace_id, id FROM authz.caller_grantees()
    WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id IN ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000001')
    ORDER BY namespace_id, id$query$,
  $values$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'::UUID), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001'), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'a0000000-0000-7000-8000-000000000001')$values$,
  'an installation with an organization permission acts through the organization, its teams and its links');
SELECT results_eq($query$SELECT resource FROM authz.granted_resources('reader', true) resource$query$,
  $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID)$values$,
  'an installation with an organization permission holds the user''s grants there');

SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, true);
SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SELECT is_empty($query$SELECT 1 FROM authz.caller_grantees()
    WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id IN ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000001')$query$,
  'an installation without an organization permission acts through no organization, team or link there');
SELECT is_empty($query$SELECT 1 FROM authz.granted_resources('reader', true)$query$,
  'an installation without an organization permission holds none of the user''s grants there');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
