\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(40);

-- Each user receives a generated creation namespace.
SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000004');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000006');
SET ROLE identity_writer;
SELECT throws_ok(format('INSERT INTO users (id, owned_namespace_id) VALUES (%L, %L)', '10000000-0000-7000-8000-000000000006', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')), '42501', NULL, 'the identity writer cannot choose the namespace a user creates in');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001') ON CONFLICT DO NOTHING;
RESET ROLE;
SELECT is((SELECT count(*) FROM namespaces WHERE NOT reserved), 4::bigint, 'a refused user insert provisions no namespace');
SELECT is((SELECT count(*) FROM platform_audit_events WHERE table_name = 'namespaces'), 4::bigint, 'a user insert skipped on its key provisions no namespace');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003');
INSERT INTO user_grants (resource_id, organization_namespace_id, organization_id, role, user_id) VALUES ('20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'admin', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT is_empty($query$SELECT id FROM authz.caller_grantees() WHERE id = '10000000-0000-7000-8000-000000000001'$query$, 'a user has no grantee row');

-- Equal local ids name different rows in different namespaces, and one namespace holds each local id once.
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT lives_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, 'an equal local id in another namespace is another team');
SELECT lives_ok($statement$SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001')$statement$, 'a team is created under a parent another user created');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000003', 'member');
RESET ROLE;
SELECT is((SELECT count(*) FROM teams WHERE id = '30000000-0000-7000-8000-000000000001'), 2::bigint, 'both teams sharing a local id exist');
SELECT is((SELECT count(*) FROM grantees WHERE id = '30000000-0000-7000-8000-000000000001'), 2::bigint, 'both teams sharing a local id are grantees');

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'a namespace holds one team per local id');
SELECT throws_ok($statement$INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('0f', 32), 'hex'), '10000000-0000-7000-8000-000000000001')$statement$, '23505', NULL, 'a link cannot take the local id of a team in the same namespace');

-- A caller creates only in its own namespace, whether another namespace is occupied, absent or reserved.
SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'a caller cannot create in another user''s namespace');
SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (gen_random_uuid(), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'a caller cannot create in an absent namespace');
SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212', '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'a caller cannot create in the reserved namespace');
SELECT throws_ok($statement$INSERT INTO organizations (namespace_id, id, created_by_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'a caller cannot found an organization in another user''s namespace');
RESET ROLE;
SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212', '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001')$statement$, '23514', NULL, 'the reserved namespace holds no team even for the owner');

-- Grants, team walks and visibility compare both components.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000001', 'team', 'reader');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SET ROLE app;
SELECT set_eq($query$SELECT namespace_id, id FROM authz.caller_grantees() WHERE id IN ('30000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000002')$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000002'::uuid), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001'::uuid)$expected$, 'a team member reaches the parent pair and not the equal local id in its own namespace');
SELECT is_empty($query$SELECT id FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$query$, 'a grant to an equal local id in another namespace reads nothing');
SELECT is((SELECT count(*) FROM grantees WHERE id = '30000000-0000-7000-8000-000000000001'), 2::bigint, 'a member sees the grantee row of each team of its organization');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', 'team', 'reader');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SET ROLE app;
SELECT results_eq($query$SELECT id FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$query$, $expected$VALUES ('40000000-0000-7000-8000-000000000001'::uuid)$expected$, 'a grant to a parent team in another namespace reaches the child team''s members');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000004');
SET ROLE app;
SELECT is((SELECT count(*) FROM grantees WHERE id = '30000000-0000-7000-8000-000000000001'), 0::bigint, 'an outsider sees no team grantee row');
RESET ROLE;

-- Audit history records namespace pairs.
SELECT results_eq($query$SELECT organization_namespace_id, actor_id, new_row ->> 'namespace_id' FROM audit_events WHERE table_name = 'teams' AND new_row ->> 'id' = '30000000-0000-7000-8000-000000000001' ORDER BY id$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '10000000-0000-7000-8000-000000000001'::uuid, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text), (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '10000000-0000-7000-8000-000000000002'::uuid, pg_temp.namespace_of('10000000-0000-7000-8000-000000000002')::text)$expected$, 'audit rows carry the organization, actor and row namespaces');

-- An installation creates in its own namespace when it acts alone, and is named by both settings together.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO apps (id, organization_namespace_id, organization_id, name) VALUES ('80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', 'namespace app');
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO app_installations (namespace_id, id, app_id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_blocks (organization_namespace_id, organization_id, installation_namespace_id, installation_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '90000000-0000-7000-8000-000000000001');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT owned_namespace_id AS installation_namespace FROM app_installations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '90000000-0000-7000-8000-000000000001' \gset
SELECT isnt(:'installation_namespace'::uuid, pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'an installation owns a namespace apart from the one it was created in');

SELECT pg_temp.act(NULL);
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, false), set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SET ROLE app;
SELECT is((SELECT authz.caller_namespace()), :'installation_namespace'::uuid, 'an installation acting alone creates in its own namespace');
SELECT results_eq($query$SELECT namespace_id, id FROM authz.caller_grantees() WHERE id = '90000000-0000-7000-8000-000000000001'$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001'::uuid)$expected$, 'an installation acting alone is its own grantee pair');
SELECT results_eq($query$SELECT namespace_id, id, owned_namespace_id FROM app_installations$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '90000000-0000-7000-8000-000000000001'::uuid, $expected$ || quote_literal(:'installation_namespace') || $expected$::uuid)$expected$, 'an installation acting alone reads its own row and no equal local id elsewhere');
SELECT is_empty($query$SELECT * FROM authz.blocking_organizations()$query$, 'a block on an equal local id in another namespace does not block the installation');
RESET ROLE;
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000002')::text, false);
SET ROLE app;
SELECT results_eq($query$SELECT * FROM authz.blocking_organizations()$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'::uuid)$expected$, 'a block on the installation pair blocks it');
SELECT is_empty($query$SELECT * FROM app_installations$query$, 'an installation its organization blocks does not read its own row');
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'an installation its organization blocks resolves no namespace');
RESET ROLE;
SELECT set_config('app.installation_namespace_id', gen_random_uuid()::text, false);
SET ROLE app;
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'an installation id under another namespace resolves no namespace');
SELECT is_empty($query$SELECT * FROM authz.caller_grantees() WHERE id = '90000000-0000-7000-8000-000000000001'$query$, 'an installation id under another namespace is no grantee');
RESET ROLE;
SELECT set_config('app.installation_namespace_id', '', false);
SET ROLE app;
SELECT throws_ok($statement$SELECT authz.acting_installation_id()$statement$, '22023', 'incomplete installation identity', 'an installation id without its namespace is refused');
RESET ROLE;
SELECT set_config('app.installation_namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001')::text, false), set_config('app.user_id', '10000000-0000-7000-8000-000000000002', false);
SET ROLE app;
SELECT is((SELECT authz.caller_namespace()), pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), 'a present user''s namespace takes precedence over the installation''s');
RESET ROLE;
SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000005', false);
SET ROLE app;
SELECT is((SELECT authz.caller_namespace()), NULL::uuid, 'an unprovisioned present user never falls back to the installation namespace');
RESET ROLE;
SELECT lives_ok($statement$DELETE FROM app_installations WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '90000000-0000-7000-8000-000000000001'$statement$, 'owner can delete an installation');
SELECT is((SELECT count(*) FROM namespaces WHERE id = :'installation_namespace'::uuid), 1::bigint, 'an installation namespace survives detached from its installation');

-- A link is presented by its full identity.
SELECT pg_temp.act('10000000-0000-7000-8000-000000000003');
SET ROLE app;
INSERT INTO share_links (namespace_id, id, organization_namespace_id, organization_id, token_hash, created_by_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000003'), 'a0000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', decode(repeat('0a', 32), 'hex'), '10000000-0000-7000-8000-000000000003');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO grants (resource_id, organization_namespace_id, organization_id, grantee_namespace_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000003'), 'a0000000-0000-7000-8000-000000000001', 'link', 'reader');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT pg_temp.act(NULL);
SELECT set_config('app.link_ids', jsonb_build_array(jsonb_build_object('namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'id', 'a0000000-0000-7000-8000-000000000001'))::text, false);
SET ROLE app;
SELECT is_empty($query$SELECT id FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$query$, 'a link id presented under another namespace reads nothing');
RESET ROLE;
SELECT set_config('app.link_ids', jsonb_build_array(jsonb_build_object('namespace_id', pg_temp.namespace_of('10000000-0000-7000-8000-000000000003'), 'id', 'a0000000-0000-7000-8000-000000000001'))::text, false);
SET ROLE app;
SELECT results_eq($query$SELECT id FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$query$, $expected$VALUES ('40000000-0000-7000-8000-000000000001'::uuid)$expected$, 'a link presented by its pair reads its grant');
RESET ROLE;
SELECT set_config('app.link_ids', '[{"id": "a0000000-0000-7000-8000-000000000001"}]', false);
SET ROLE app;
SELECT throws_ok($statement$SELECT * FROM authz.link_ids()$statement$, '22023', 'incomplete link identity', 'a link id without its namespace is refused');
RESET ROLE;
SELECT set_config('app.link_ids', 'a0000000-0000-7000-8000-000000000001', false);
SET ROLE app;
SELECT throws_ok($statement$SELECT * FROM authz.link_ids()$statement$, '22P02', NULL, 'a bare link id is refused');
RESET ROLE;

SELECT pg_temp.act(NULL);
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
