\set ON_ERROR_STOP 1
CREATE FUNCTION pg_temp.audit_check(check_name TEXT, action_sql TEXT, assertion_sql TEXT,
  expected_errors TEXT[] DEFAULT ARRAY[]::TEXT[]) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  passed BOOLEAN := FALSE;
  detail TEXT := '';
BEGIN
  BEGIN
    EXECUTE action_sql;
    EXECUTE assertion_sql INTO passed;
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION USING ERRCODE = 'Z0001', MESSAGE = 'rollback audit scenario';
  EXCEPTION
    WHEN SQLSTATE 'Z0001' THEN NULL;
    WHEN OTHERS THEN
      passed := SQLSTATE = ANY (expected_errors);
      detail := format(' [%s] %s', SQLSTATE, SQLERRM);
  END;
  IF passed IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL % %', check_name, detail;
  END IF;
  RETURN 'PASS ' || check_name;
END
$$;
GRANT EXECUTE ON FUNCTION pg_temp.audit_check(TEXT, TEXT, TEXT, TEXT[]) TO app, identity_writer;
-- Identity layer writes two users.
SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;

CREATE FUNCTION pg_temp.act(principal TEXT) RETURNS VOID LANGUAGE sql AS $$
  SELECT set_config('app.user_id', coalesce(principal, ''), false), set_config('app.installation_id', '', false),
         set_config('app.link_ids', '', false), set_config('app.original_actor_id', '', false),
         set_config('app.verified_email', '', false)
$$;
CREATE FUNCTION pg_temp.found_organization(organization UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.organizations (id, created_by_id) VALUES (organization, authz.caller_id());
  INSERT INTO public.resources (id, kind, organization_id) VALUES (organization, 'organization', organization);
  INSERT INTO public.memberships (organization_id, user_id, state) VALUES (organization, authz.caller_id(), 'active');
  INSERT INTO public.grants (organization_id, resource_id, grantee_id, grantee_kind, role)
    VALUES (organization, organization, authz.caller_id(), 'user', 'admin');
$$;
CREATE FUNCTION pg_temp.create_child_team(team UUID, parent UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.teams (id, organization_id)
    SELECT team, ancestor.organization_id FROM public.teams ancestor WHERE ancestor.id = parent;
  INSERT INTO public.team_parents (organization_id, id, parent_id)
    SELECT ancestor.organization_id, team, parent FROM public.teams ancestor WHERE ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_child_resource(child UUID, child_kind authz.resource_kind, parent UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.resources (id, kind, organization_id)
    SELECT child, child_kind, ancestor.organization_id FROM public.resources ancestor WHERE ancestor.id = parent;
  INSERT INTO public.resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
    SELECT ancestor.organization_id, child, child_kind, parent, ancestor.kind FROM public.resources ancestor WHERE ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_ownable(ownable UUID, organization UUID, project UUID, creator UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.ownables (id, organization_id, project_id, created_by_id) VALUES (ownable, organization, project, creator);
  INSERT INTO public.resources (id, kind, organization_id) VALUES (ownable, 'ownable', organization);
$$;
CREATE FUNCTION pg_temp.accept_invitation(invitation UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.memberships (organization_id, user_id, state, invitation_id)
    SELECT pending.organization_id, authz.caller_id(), 'active', invitation FROM public.invitations pending WHERE pending.id = invitation;
$$;
GRANT EXECUTE ON FUNCTION pg_temp.found_organization(UUID), pg_temp.create_child_team(UUID, UUID),
  pg_temp.create_child_resource(UUID, authz.resource_kind, UUID), pg_temp.create_ownable(UUID, UUID, UUID, UUID),
  pg_temp.accept_invitation(UUID) TO app;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.audit_check('org visible', 'SELECT 1', 'SELECT count(*) = 1 FROM organizations');
INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_team('30000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000001');
SELECT pg_temp.audit_check('team cannot parent itself',
  $$UPDATE team_parents SET parent_id = '30000000-0000-7000-8000-000000000002' WHERE id = '30000000-0000-7000-8000-000000000002'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('team cycle is rejected',
  $$INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000002')$$,
  'SELECT FALSE', ARRAY['23514']);
-- Folder, project, ownable, then archive and restore.
BEGIN;
INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-000000000001', 'folder', '20000000-0000-7000-8000-000000000001', 'organization');
COMMIT;
SELECT pg_temp.audit_check('top-level folder has organization edge', 'SELECT 1',
  $$SELECT EXISTS (SELECT 1 FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000001' AND parent_id = '20000000-0000-7000-8000-000000000001')$$);
SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-000000000002', 'folder', '40000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000001', 'project', '40000000-0000-7000-8000-000000000002');
SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000002', 'project', '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000001');
SELECT pg_temp.audit_check('organization archive reaches nested ownable',
  $$UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001'$$,
  $$SELECT authz.is_archived('60000000-0000-7000-8000-000000000001')$$);
SELECT pg_temp.audit_check('organization archive blocks ownable writes',
  $$UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001';
    UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001'$$,
  $$SELECT project_id = '50000000-0000-7000-8000-000000000001' FROM ownables WHERE id = '60000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('folder without edge is rejected',
  $$INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-000000000099', 'folder', '20000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('project cannot parent a resource',
  $$UPDATE resource_parents SET parent_id = '50000000-0000-7000-8000-000000000002', parent_kind = 'project' WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('required edge cannot be removed',
  $$DELETE FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000002'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('organization edge audit includes typed parent', 'SELECT 1',
  $$SELECT EXISTS (SELECT 1 FROM audit_events WHERE table_name = 'resource_parents' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000001' AND new_row ->> 'parent_kind' = 'organization' AND new_row ->> 'parent_id' = '20000000-0000-7000-8000-000000000001')$$);
UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000002' WHERE id = '60000000-0000-7000-8000-000000000001';
SELECT pg_temp.audit_check('moved', 'SELECT 1',
  $$SELECT count(*) = 1 AND bool_and(project_id = '50000000-0000-7000-8000-000000000002') FROM ownables$$);
UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = '50000000-0000-7000-8000-000000000001';
SELECT pg_temp.audit_check('archived project rows updated', 'SELECT 1',
  $$SELECT count(*) = 0 FROM resources WHERE kind = 'project' AND writers_can_share$$);
SELECT pg_temp.audit_check('restore under archived organization is refused',
  $$UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001';
    UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  $$SELECT archived_at IS NOT NULL FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$$);
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001';
UPDATE resources SET writers_can_share = TRUE WHERE id = '50000000-0000-7000-8000-000000000001';
SELECT pg_temp.audit_check('restored project rows updated', 'SELECT 1',
  $$SELECT count(*) = 1 FROM resources WHERE kind = 'project' AND writers_can_share$$);
-- Invitation accepted by the second user.
INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'b@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SELECT set_config('app.verified_email', 'b@example.com', false);
SET ROLE app;
SELECT pg_temp.audit_check('invitee sees invitation', 'SELECT 1', 'SELECT count(*) = 1 FROM invitations');
SELECT pg_temp.accept_invitation('70000000-0000-7000-8000-000000000001');
SELECT pg_temp.audit_check('server marks the invitation accepted', 'SELECT 1',
  $$SELECT accepted_by_id = '10000000-0000-7000-8000-000000000002' FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('member sees memberships', 'SELECT 1', 'SELECT count(*) = 2 FROM memberships');
SELECT pg_temp.audit_check('member without grant sees projects', 'SELECT 1',
  $$SELECT count(*) = 0 FROM resources WHERE kind = 'project'$$);
SELECT pg_temp.audit_check('member cannot create child team',
  $$SELECT pg_temp.create_child_team('30000000-0000-7000-8000-000000000003', '30000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['42501']);
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.audit_check('last admin cannot be deleted',
  $$DELETE FROM grants WHERE grantee_id = '10000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('audit events', 'SELECT 1',
  $$SELECT array_agg(table_name || ' ' || operation ORDER BY id) = ARRAY[
    'resources INSERT', 'memberships INSERT', 'grants INSERT', 'teams INSERT',
    'teams INSERT', 'team_parents INSERT', 'resources INSERT', 'resource_parents INSERT',
    'resources INSERT', 'resource_parents INSERT', 'resources INSERT', 'resource_parents INSERT',
    'resources INSERT', 'resource_parents INSERT', 'ownables INSERT', 'resources INSERT', 'ownables UPDATE',
    'resources UPDATE', 'resources UPDATE', 'resources UPDATE', 'invitations INSERT',
    'memberships INSERT', 'invitations UPDATE'
  ] AND bool_and(actor_id IS NOT NULL) FROM audit_events$$);

RESET ROLE;

SELECT pg_temp.audit_check('platform audit records user creation and organization founding', 'SELECT 1',
  $$SELECT array_agg(table_name || ' ' || operation ORDER BY id) = ARRAY['users INSERT', 'users INSERT', 'organizations INSERT']
    AND bool_and((table_name = 'users') = (actor_id IS NULL)) FROM platform_audit_events$$);
SELECT pg_temp.audit_check('platform operator reads platform audit',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SET LOCAL ROLE app$$,
  $$SELECT array_agg(table_name || ' ' || operation ORDER BY id) = ARRAY[
    'users INSERT', 'users INSERT', 'organizations INSERT', 'platform_operators INSERT'] FROM platform_audit_events$$);
SELECT pg_temp.audit_check('platform audit is hidden from organization admins',
  'SET LOCAL ROLE app', 'SELECT count(*) = 0 FROM platform_audit_events');
SELECT pg_temp.audit_check('platform audit is hidden from installations acting for an operator',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000099', true);
    SET LOCAL ROLE app$$,
  'SELECT count(*) = 0 FROM platform_audit_events');
SELECT pg_temp.audit_check('platform operator reads their own operator row',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SET LOCAL ROLE app$$,
  $$SELECT array_agg(id) = ARRAY['10000000-0000-7000-8000-000000000002'::uuid] FROM platform_operators$$);
SELECT pg_temp.audit_check('platform operator rows are hidden from other users',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000001', true);
    SET LOCAL ROLE app$$,
  'SELECT count(*) = 0 FROM platform_operators');
SELECT pg_temp.audit_check('platform operator rows are hidden from installations acting for an operator',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000099', true);
    SET LOCAL ROLE app$$,
  'SELECT count(*) = 0 FROM platform_operators');

SELECT pg_temp.audit_check('support operator cannot receive a permanent grant',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SET LOCAL ROLE app;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('permanent grant prevents operator registration',
  $$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader');
    INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('support grant accepts any finite expiry',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SET LOCAL ROLE app;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader', now() + interval '100 years')$$,
  $$SELECT expires_at = now() + interval '100 years' FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000002'$$);
SELECT pg_temp.audit_check('support grant expiry cannot be removed',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SET LOCAL ROLE app;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader', now() + interval '1 day');
    UPDATE grants SET expires_at = NULL WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000002'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('support grant rejects infinite expiry',
  $$INSERT INTO platform_operators (id) VALUES ('10000000-0000-7000-8000-000000000002');
    SET LOCAL ROLE app;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader', 'infinity')$$,
  'SELECT FALSE', ARRAY['23514']);
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT pg_temp.audit_check('ordinary user may receive a permanent grant',
  $$SET LOCAL ROLE app;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'reader')$$,
  $$SELECT expires_at IS NULL FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000002'$$);
COMMIT;

SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000002');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000003');
BEGIN;
INSERT INTO resources (id, kind, organization_id) VALUES
  ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
COMMIT;
SELECT pg_temp.audit_check('resource cannot cross organizations',
  $$UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001' WHERE id = '40000000-0000-7000-8000-000000000003'$$,
  'SELECT FALSE', ARRAY['23503']);
INSERT INTO memberships (organization_id, user_id, state) VALUES
  ('20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'active');
INSERT INTO teams (id, organization_id) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002'),
  ('30000000-0000-7000-8000-000000000005', '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES
  ('30000000-0000-7000-8000-000000000004', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001', 'admin');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
  ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer'),
  ('50000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'writer'),
  ('20000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000002', 'user', 'admin'),
  ('40000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000002', '30000000-0000-7000-8000-000000000005', 'team', 'reader'),
  ('20000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team', 'admin');
INSERT INTO apps (id, organization_id, name) VALUES
  ('80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'audit app');
INSERT INTO app_installations (id, app_id, organization_id) VALUES
  ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001');
INSERT INTO installation_permissions (installation_id, organization_id, kind, max_role) VALUES
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'folder', 'admin'),
  ('90000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'organization', 'admin');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000003', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', decode(repeat('01', 32), 'hex'), '10000000-0000-7000-8000-000000000002'),
  ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', decode(repeat('02', 32), 'hex'), '10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
UPDATE share_links SET revoked_at = now() WHERE id = 'a0000000-0000-7000-8000-000000000001';

SELECT set_config('app.installation_id', '90000000-0000-7000-8000-000000000001', false);
SELECT pg_temp.audit_check('1 installation cannot read another organization', 'SELECT 1',
  $$SELECT NOT EXISTS (SELECT 1 FROM resources WHERE id = '40000000-0000-7000-8000-000000000003')$$);
SELECT pg_temp.audit_check('1 installation cannot write another organization',
  $$UPDATE resources SET writers_can_share = TRUE WHERE id = '40000000-0000-7000-8000-000000000003';
    SELECT set_config('app.installation_id', '', true)$$,
  $$SELECT NOT writers_can_share FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'$$, ARRAY['42501']);
SELECT pg_temp.audit_check('1 membership helper stays in installation organization', 'SELECT 1',
  $$SELECT NOT EXISTS (SELECT 1 FROM authz.member_organizations() organization_id WHERE organization_id = '20000000-0000-7000-8000-000000000002')$$);
SELECT pg_temp.audit_check('1 team administration stays in installation organization', 'SELECT 1',
  $$SELECT NOT EXISTS (SELECT 1 FROM authz.administered_teams() team_id WHERE team_id = '30000000-0000-7000-8000-000000000004')$$);
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.audit_check('2 writer cannot enable sharing',
  $$UPDATE resources SET writers_can_share = TRUE WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  $$SELECT NOT writers_can_share FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$$, ARRAY['42501']);
SELECT pg_temp.audit_check('2 writer cannot archive',
  $$UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  $$SELECT archived_at IS NULL FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$$, ARRAY['42501']);
SELECT pg_temp.audit_check('2 writer cannot restore',
  $$RESET ROLE;
    UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000001';
    SET ROLE app;
    UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  $$SELECT archived_at IS NOT NULL FROM resources WHERE id = '40000000-0000-7000-8000-000000000001'$$, ARRAY['42501']);
SELECT pg_temp.audit_check('6 creator cannot undo admin revocation',
  $$UPDATE share_links SET revoked_at = NULL WHERE id = 'a0000000-0000-7000-8000-000000000001'$$,
  $$SELECT revoked_at IS NOT NULL FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000001'$$, ARRAY['42501']);
SELECT pg_temp.audit_check('7 writer cannot move ownable',
  $$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000001' WHERE id = '60000000-0000-7000-8000-000000000001'$$,
  $$SELECT project_id = '50000000-0000-7000-8000-000000000002' FROM ownables WHERE id = '60000000-0000-7000-8000-000000000001'$$, ARRAY['42501']);

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SELECT id AS audience_id FROM grantees WHERE kind = 'everyone' \gset
SET ROLE app;
SELECT pg_temp.audit_check('database stamps archived_at update',
  $$UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003'$$,
  $$SELECT archived_at = now() AND EXISTS (SELECT 1 FROM audit_events WHERE table_name = 'resources' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000003' AND (new_row ->> 'archived_at')::timestamptz = now()) FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'$$);
RESET ROLE;
SELECT pg_temp.audit_check('database stamps archived_at insert',
  $$INSERT INTO resources (id, kind, organization_id, archived_at) VALUES ('40000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000002', '2000-01-01');
    INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
      VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000002', 'organization')$$,
  $$SELECT archived_at = now() AND EXISTS (SELECT 1 FROM audit_events WHERE table_name = 'resources' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000009' AND (new_row ->> 'archived_at')::timestamptz = now()) FROM resources WHERE id = '40000000-0000-7000-8000-000000000009'$$);
SET ROLE app;
UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT archived_at AS original_archive_time FROM resources WHERE id = '40000000-0000-7000-8000-000000000003' \gset
RESET ROLE;
SELECT pg_temp.audit_check('stored archive timestamp is immutable',
  $$UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003'$$,
  format('SELECT archived_at = %L::timestamptz FROM resources WHERE id = %L', :'original_archive_time', '40000000-0000-7000-8000-000000000003'));
SET ROLE app;
SELECT pg_temp.audit_check('database stamps archived_at preserve',
  $$UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003'$$,
  format('SELECT archived_at = %L::timestamptz FROM resources WHERE id = %L', :'original_archive_time', '40000000-0000-7000-8000-000000000003'));
UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT pg_temp.audit_check('archive restoration keeps null', 'SELECT 1',
  $$SELECT archived_at IS NULL FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'$$);
SELECT pg_temp.audit_check('database stamps revoked_at update',
  $$UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003'$$,
  $$SELECT revoked_at = now() AND EXISTS (SELECT 1 FROM audit_events WHERE table_name = 'share_links' AND new_row ->> 'id' = 'a0000000-0000-7000-8000-000000000003' AND (new_row ->> 'revoked_at')::timestamptz = now()) FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003'$$);
SELECT pg_temp.audit_check('database stamps revoked_at insert',
  $$INSERT INTO share_links (id, organization_id, token_hash, created_by_id, revoked_at) VALUES ('a0000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000003', decode(repeat('09', 32), 'hex'), '10000000-0000-7000-8000-000000000001', '2000-01-01')$$,
  $$SELECT revoked_at = now() AND EXISTS (SELECT 1 FROM audit_events WHERE table_name = 'share_links' AND new_row ->> 'id' = 'a0000000-0000-7000-8000-000000000009' AND (new_row ->> 'revoked_at')::timestamptz = now()) FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000009'$$);
UPDATE share_links SET revoked_at = now() WHERE id = 'a0000000-0000-7000-8000-000000000003';
SELECT revoked_at AS original_revocation_time FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003' \gset
RESET ROLE;
SELECT pg_temp.audit_check('stored revocation timestamp is immutable',
  $$UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003'$$,
  format('SELECT revoked_at = %L::timestamptz FROM share_links WHERE id = %L', :'original_revocation_time', 'a0000000-0000-7000-8000-000000000003'));
SET ROLE app;
SELECT pg_temp.audit_check('database stamps revoked_at preserve',
  $$UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003'$$,
  format('SELECT revoked_at = %L::timestamptz FROM share_links WHERE id = %L', :'original_revocation_time', 'a0000000-0000-7000-8000-000000000003'));
SELECT pg_temp.audit_check('3 audience cannot hold admin',
  format('INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES (%L, %L, %L, %L, %L)', '40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', :'audience_id', 'everyone', 'admin'),
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('3 link cannot hold admin',
  $$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link', 'admin')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('3 empty team cannot replace last user admin',
  $$DELETE FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000001' AND grantee_id = '10000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('4 deactivated member loses direct admin',
  $$UPDATE memberships SET state = 'deactivated' WHERE organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM authz.resources_with('admin') resource_id WHERE resource_id = '20000000-0000-7000-8000-000000000002')$$);
SELECT pg_temp.audit_check('4 removed member loses direct admin',
  $$DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000002' AND user_id = '10000000-0000-7000-8000-000000000001'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM authz.resources_with('admin') resource_id WHERE resource_id = '20000000-0000-7000-8000-000000000002')$$);
SELECT pg_temp.audit_check('7 move needs destination writer',
  $$SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000003', 'project', '20000000-0000-7000-8000-000000000001');
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000003' WHERE id = '60000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('7 admin can move ownable',
  $$UPDATE ownables SET project_id = '50000000-0000-7000-8000-000000000001' WHERE id = '60000000-0000-7000-8000-000000000001'$$,
  $$SELECT project_id = '50000000-0000-7000-8000-000000000001' FROM ownables WHERE id = '60000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('8 team insert is idempotent',
  $$INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001') ON CONFLICT (id) DO NOTHING$$,
  $$SELECT count(*) = 1 FROM teams WHERE id = '30000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('8 installation insert is idempotent',
  $$INSERT INTO app_installations (id, app_id, organization_id) VALUES ('90000000-0000-7000-8000-000000000001', '80000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001') ON CONFLICT (id) DO NOTHING$$,
  $$SELECT count(*) = 1 FROM app_installations WHERE id = '90000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('8 ownable insert is idempotent',
  $$INSERT INTO ownables (id, organization_id, project_id, created_by_id) VALUES ('60000000-0000-7000-8000-000000000001', '20000000-0000-7000-8000-000000000001', '50000000-0000-7000-8000-000000000002', '10000000-0000-7000-8000-000000000001') ON CONFLICT (id) DO NOTHING$$,
  $$SELECT count(*) = 1 FROM ownables WHERE id = '60000000-0000-7000-8000-000000000001'$$);
SELECT pg_temp.audit_check('9 team deletion cascades cross-organization grants',
  $$DELETE FROM teams WHERE id = '30000000-0000-7000-8000-000000000005'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM teams WHERE id = '30000000-0000-7000-8000-000000000005')
    AND NOT EXISTS (SELECT 1 FROM grants WHERE grantee_id = '30000000-0000-7000-8000-000000000005')$$);
SELECT pg_temp.audit_check('9 admin can delete share link',
  $$DELETE FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002')$$);
SELECT pg_temp.audit_check('10 invitation acceptance cannot be forged',
  $$INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id, accepted_by_id) VALUES
    ('70000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', 'forged@example.com', now() + interval '1 day',
      '10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('11 team block is rejected',
  $$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', '30000000-0000-7000-8000-000000000001', 'team')$$,
  'SELECT FALSE', ARRAY['23514', '23503']);
SELECT pg_temp.audit_check('11 link block is rejected',
  $$INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES ('20000000-0000-7000-8000-000000000001', 'a0000000-0000-7000-8000-000000000002', 'link')$$,
  'SELECT FALSE', ARRAY['23514', '23503']);
SELECT pg_temp.audit_check('11 audience block is rejected',
  format('INSERT INTO organization_blocks (organization_id, principal_id, principal_kind) VALUES (%L, %L, %L)', '20000000-0000-7000-8000-000000000001', :'audience_id', 'everyone'),
  'SELECT FALSE', ARRAY['23514', '23503']);
RESET ROLE;
SET ROLE identity_writer;
SELECT pg_temp.audit_check('8 user insert is idempotent',
  $$INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001') ON CONFLICT (id) DO NOTHING$$,
  $$SELECT count(*) = 1 FROM users WHERE id = '10000000-0000-7000-8000-000000000001'$$);
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT pg_temp.audit_check('8 link insert is idempotent',
  $$INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
    ('a0000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', decode(repeat('02', 32), 'hex'), '10000000-0000-7000-8000-000000000002') ON CONFLICT (id) DO NOTHING$$,
  $$SELECT count(*) = 1 FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000002'$$);
RESET ROLE;
SELECT pg_temp.audit_check('9 organization deletion after link and dependent cleanup',
  $$DELETE FROM share_links WHERE organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM resources WHERE organization_id = '20000000-0000-7000-8000-000000000003';
    DELETE FROM organizations WHERE id = '20000000-0000-7000-8000-000000000003'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM organizations WHERE id = '20000000-0000-7000-8000-000000000003')
    AND NOT EXISTS (SELECT 1 FROM share_links WHERE organization_id = '20000000-0000-7000-8000-000000000003')
    AND NOT EXISTS (SELECT 1 FROM grantees WHERE id = 'a0000000-0000-7000-8000-000000000003')
    AND EXISTS (SELECT 1 FROM platform_audit_events WHERE table_name = 'organizations' AND operation = 'DELETE'
      AND old_row ->> 'id' = '20000000-0000-7000-8000-000000000003')$$);

SET ROLE app;
SELECT pg_temp.audit_check('organization grant reaches nested ownable',
  $$SELECT pg_temp.create_child_resource('50000000-0000-7000-8000-000000000099', 'project', '40000000-0000-7000-8000-000000000003');
    SELECT pg_temp.create_ownable('60000000-0000-7000-8000-000000000099', '20000000-0000-7000-8000-000000000002', '50000000-0000-7000-8000-000000000099', '10000000-0000-7000-8000-000000000002')$$,
  $$SELECT EXISTS (SELECT 1 FROM authz.resources_with('reader') resource_id WHERE resource_id = '60000000-0000-7000-8000-000000000099')$$);
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.audit_check('twenty resource levels exclude organization',
  $action$DO $body$
  DECLARE
    level INTEGER;
    parent UUID := '20000000-0000-7000-8000-000000000001';
    child UUID;
  BEGIN
    FOR level IN 1..20 LOOP
      child := ('d0000000-0000-7000-8000-' || lpad(level::text, 12, '0'))::uuid;
      PERFORM pg_temp.create_child_resource(child, CASE WHEN level = 20 THEN 'project'::authz.resource_kind ELSE 'folder'::authz.resource_kind END, parent);
      parent := child;
    END LOOP;
  END
  $body$;
  SELECT pg_temp.create_ownable('d0000000-0000-7000-8000-000000000021', '20000000-0000-7000-8000-000000000001', 'd0000000-0000-7000-8000-000000000020', '10000000-0000-7000-8000-000000000001');
  UPDATE resources SET archived_at = now() WHERE id = '20000000-0000-7000-8000-000000000001'$action$,
  $$SELECT authz.is_archived('d0000000-0000-7000-8000-000000000021')$$);
SELECT pg_temp.audit_check('twenty-one resource levels are rejected',
  $action$DO $body$
  DECLARE
    level INTEGER;
    parent UUID := '20000000-0000-7000-8000-000000000001';
    child UUID;
  BEGIN
    FOR level IN 1..21 LOOP
      child := ('d0000000-0000-7000-8000-' || lpad(level::text, 12, '0'))::uuid;
      PERFORM pg_temp.create_child_resource(child, 'folder', parent);
      parent := child;
    END LOOP;
  END
  $body$$action$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('resource cycle is rejected',
  $$UPDATE resource_parents SET parent_id = '40000000-0000-7000-8000-000000000002', parent_kind = 'folder' WHERE id = '40000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('folder can move to organization',
  $$UPDATE resource_parents SET parent_id = '20000000-0000-7000-8000-000000000001', parent_kind = 'organization' WHERE id = '40000000-0000-7000-8000-000000000002'$$,
  $$SELECT parent_kind = 'organization' FROM resource_parents WHERE id = '40000000-0000-7000-8000-000000000002'$$);
SELECT pg_temp.audit_check('organization without an admin is refused',
  $$INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('organization creator is the caller',
  $$INSERT INTO organizations (id, created_by_id) VALUES ('20000000-0000-7000-8000-000000000005', '10000000-0000-7000-8000-000000000002')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('only the founder takes the founding grant',
  $$SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000006');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000006', '20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000002', 'user', 'admin')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('demoted founder cannot grant itself admin again',
  $$SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000006');
    INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000002', 'active');
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000006', '20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
    DELETE FROM grants WHERE resource_id = '20000000-0000-7000-8000-000000000006' AND grantee_id = '10000000-0000-7000-8000-000000000001';
    SET CONSTRAINTS ALL IMMEDIATE;
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000006', '20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000001', 'user', 'admin')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('removed founder cannot rejoin',
  $$SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000006');
    INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000002', 'active');
    INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES
      ('20000000-0000-7000-8000-000000000006', '20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
    SET CONSTRAINTS ALL IMMEDIATE;
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000006' AND user_id = '10000000-0000-7000-8000-000000000001';
    SET CONSTRAINTS ALL IMMEDIATE;
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000001', true);
    INSERT INTO memberships (organization_id, user_id, state) VALUES ('20000000-0000-7000-8000-000000000006', '10000000-0000-7000-8000-000000000001', 'active')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('folder admin creates a child folder',
  $$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT pg_temp.create_child_resource('40000000-0000-7000-8000-00000000000a', 'folder', '40000000-0000-7000-8000-000000000002')$$,
  $$SELECT EXISTS (SELECT 1 FROM resource_parents WHERE id = '40000000-0000-7000-8000-00000000000a' AND parent_id = '40000000-0000-7000-8000-000000000002')$$);
SELECT pg_temp.audit_check('folder admin cannot create at the organization root',
  $$INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role) VALUES ('40000000-0000-7000-8000-000000000002', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'user', 'admin');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    INSERT INTO resources (id, kind, organization_id) VALUES ('40000000-0000-7000-8000-00000000000a', 'folder', '20000000-0000-7000-8000-000000000001');
    INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
      VALUES ('20000000-0000-7000-8000-000000000001', '40000000-0000-7000-8000-00000000000a', 'folder', '20000000-0000-7000-8000-000000000001', 'organization')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('team admin creates a child team',
  $$INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000001');
    INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES ('30000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin');
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT pg_temp.create_child_team('30000000-0000-7000-8000-00000000000a', '30000000-0000-7000-8000-000000000009')$$,
  $$SELECT EXISTS (SELECT 1 FROM team_parents WHERE id = '30000000-0000-7000-8000-00000000000a' AND parent_id = '30000000-0000-7000-8000-000000000009')$$);
SELECT pg_temp.audit_check('team admin cannot create a root team',
  $$INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000001');
    INSERT INTO team_members (team_id, organization_id, user_id, team_role) VALUES ('30000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin');
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    INSERT INTO teams (id, organization_id) VALUES ('30000000-0000-7000-8000-00000000000a', '20000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('ownable resource requires its ownable',
  $$INSERT INTO resources (id, kind, organization_id) VALUES ('60000000-0000-7000-8000-00000000000a', 'ownable', '20000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['23514']);
SELECT pg_temp.audit_check('client cannot mark an invitation accepted',
  $$INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.verified_email', 'c@example.com', true);
    UPDATE invitations SET accepted_by_id = '10000000-0000-7000-8000-000000000002' WHERE id = '70000000-0000-7000-8000-000000000003'$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('invitation admits only its invitee',
  $$INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.verified_email', 'b@example.com', true);
    DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
    INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000003')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('invitation admits only its organization',
  $$INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
    SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.verified_email', 'c@example.com', true);
    INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000003', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000003')$$,
  'SELECT FALSE', ARRAY['23503']);
SELECT pg_temp.audit_check('admin cannot accept an invitation for a member',
  $$INSERT INTO invitations (id, organization_id, email, expires_at, invited_by_id) VALUES ('70000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000001', 'c@example.com', now() + interval '1 day', '10000000-0000-7000-8000-000000000001');
    DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
    INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000003')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('accepted invitation cannot be reused',
  $$SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
    SELECT set_config('app.verified_email', 'b@example.com', true);
    DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
    INSERT INTO memberships (organization_id, user_id, state, invitation_id) VALUES ('20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'active', '70000000-0000-7000-8000-000000000001')$$,
  'SELECT FALSE', ARRAY['42501']);
SELECT pg_temp.audit_check('accepted invitation stays while its member stays',
  $$DELETE FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$$,
  'SELECT FALSE', ARRAY['23503']);
SELECT pg_temp.audit_check('accepted invitation can be deleted once its member leaves',
  $$DELETE FROM memberships WHERE organization_id = '20000000-0000-7000-8000-000000000001' AND user_id = '10000000-0000-7000-8000-000000000002';
    DELETE FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001'$$,
  $$SELECT NOT EXISTS (SELECT 1 FROM invitations WHERE id = '70000000-0000-7000-8000-000000000001')$$);
RESET ROLE;
