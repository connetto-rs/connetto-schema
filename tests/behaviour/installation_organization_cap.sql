\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(4);

-- User 1 founds organization 1, joins team 1 and holds share link 1 there. Installation 1 holds
-- only a folder permission in organization 1, installation 2 an organization permission.
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001', 'member');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001'),
  ('90000000-0000-7000-8000-000000000002', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  ('90000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', 'organization', 'reader');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('app.link_ids', 'a0000000-0000-7000-8000-000000000001', false);

SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000002', false);
SELECT results_eq($query$SELECT grantee FROM authz.caller_grantees() grantee
    WHERE grantee IN ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000001')
    ORDER BY grantee$query$,
  $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID), ('30000000-0000-7000-8000-000000000001'), ('a0000000-0000-7000-8000-000000000001')$values$,
  'an installation with an organization permission acts through the organization, its teams and its links');
SELECT results_eq($query$SELECT resource FROM authz.granted_resources('reader') resource$query$,
  $values$VALUES ('20000000-0000-7000-8000-000000000001'::UUID)$values$,
  'an installation with an organization permission holds the user''s grants there');

SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SELECT is_empty($query$SELECT 1 FROM authz.caller_grantees() grantee
    WHERE grantee IN ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000001')$query$,
  'an installation without an organization permission acts through no organization, team or link there');
SELECT is_empty($query$SELECT 1 FROM authz.granted_resources('reader')$query$,
  'an installation without an organization permission holds none of the user''s grants there');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
