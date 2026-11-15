-- Definer helpers every policy calls, owned by a role past the policies of the tables they read.

GRANT SELECT ON grantees, memberships, team_members, team_parents, share_links,
  organizations, folders, folder_parents, projects, project_folders, ownables,
  organization_grants, folder_grants, project_grants, ownable_grants,
  organization_blocks, app_installations, installation_permissions TO authz_owner;

-- Everything the caller is, team ancestors included, so a grant naming any of it reaches the caller.
CREATE FUNCTION authz.caller_grantees() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT g.id FROM public.grantees g
    WHERE g.id = current_setting('app.user_id', true)::uuid AND g.kind IN ('user', 'installation')
    UNION
    SELECT g.id FROM public.grantees g WHERE g.kind = 'everyone'
    UNION
    SELECT g.id FROM public.grantees g
    WHERE g.kind = 'signed_in' AND current_setting('app.user_id', true)::uuid <> '00000000-0000-0000-0000-000000000000'
    UNION
    SELECT m.organization_id FROM public.memberships m
    WHERE m.user_id = current_setting('app.user_id', true)::uuid AND m.state = 'active'
    UNION
    SELECT tm.team_id FROM public.team_members tm
    WHERE tm.user_id = current_setting('app.user_id', true)::uuid AND tm.membership_state = 'active'
    UNION
    SELECT l.id FROM public.share_links l
    WHERE l.id = ANY (string_to_array(current_setting('app.link_ids', true), ',')::uuid[])
      AND l.revoked = FALSE AND (l.expires_at IS NULL OR l.expires_at > now())
    UNION
    SELECT tp.parent_id FROM public.team_parents tp JOIN reached ON tp.team_id = reached.id
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.organizations_with(min_role TEXT) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT og.organization_id FROM public.organization_grants og
  WHERE og.grantee_id IN (SELECT authz.caller_grantees())
    AND (og.expires_at IS NULL OR og.expires_at > now())
    AND (min_role = 'reader' OR og.role = 'admin' OR (min_role = 'writer' AND og.role = 'writer'))
$$;

-- A grant on a folder reaches every folder below it.
CREATE FUNCTION authz.folders_with(min_role TEXT) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT fg.folder_id FROM public.folder_grants fg
    WHERE fg.grantee_id IN (SELECT authz.caller_grantees())
      AND (fg.expires_at IS NULL OR fg.expires_at > now())
      AND (min_role = 'reader' OR fg.role = 'admin' OR (min_role = 'writer' AND fg.role = 'writer'))
    UNION
    SELECT f.id FROM public.folders f WHERE f.organization_id IN (SELECT authz.organizations_with(min_role))
    UNION
    SELECT fp.folder_id FROM public.folder_parents fp JOIN reached ON fp.parent_id = reached.id
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.projects_with(min_role TEXT) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT pg.project_id FROM public.project_grants pg
  WHERE pg.grantee_id IN (SELECT authz.caller_grantees())
    AND (pg.expires_at IS NULL OR pg.expires_at > now())
    AND (min_role = 'reader' OR pg.role = 'admin' OR (min_role = 'writer' AND pg.role = 'writer'))
  UNION
  SELECT p.id FROM public.projects p WHERE p.organization_id IN (SELECT authz.organizations_with(min_role))
  UNION
  SELECT pf.project_id FROM public.project_folders pf WHERE pf.folder_id IN (SELECT authz.folders_with(min_role))
$$;

CREATE FUNCTION authz.ownables_with(min_role TEXT) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT og.ownable_id FROM public.ownable_grants og
  WHERE og.grantee_id IN (SELECT authz.caller_grantees())
    AND (og.expires_at IS NULL OR og.expires_at > now())
    AND (min_role = 'reader' OR og.role = 'admin' OR (min_role = 'writer' AND og.role = 'writer'))
  UNION
  SELECT o.id FROM public.ownables o WHERE o.project_id IN (SELECT authz.projects_with(min_role))
$$;

-- Organizations whose active members include the caller.
CREATE FUNCTION authz.member_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT m.organization_id FROM public.memberships m
  WHERE m.user_id = current_setting('app.user_id', true)::uuid AND m.state = 'active'
$$;

-- Users sharing an active membership with the caller.
CREATE FUNCTION authz.co_member_users() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT m.user_id FROM public.memberships m
  WHERE m.organization_id IN (SELECT authz.member_organizations()) AND m.state = 'active'
$$;

CREATE FUNCTION authz.administered_teams() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT tm.team_id FROM public.team_members tm
  WHERE tm.user_id = current_setting('app.user_id', true)::uuid
    AND tm.team_role = 'admin' AND tm.membership_state = 'active'
$$;

CREATE FUNCTION authz.administered_installations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT ai.id FROM public.app_installations ai WHERE ai.organization_id IN (SELECT authz.organizations_with('admin'))
$$;

CREATE FUNCTION authz.writers_share_folders() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT f.id FROM public.folders f WHERE f.writers_can_share = TRUE
$$;

CREATE FUNCTION authz.writers_share_projects() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p.id FROM public.projects p WHERE p.writers_can_share = TRUE
$$;

CREATE FUNCTION authz.writers_share_ownables() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT o.id FROM public.ownables o WHERE o.writers_can_share = TRUE
$$;

CREATE FUNCTION authz.archived_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT o.id FROM public.organizations o WHERE o.archived = TRUE
$$;

-- An archived folder freezes every folder below it.
CREATE FUNCTION authz.archived_folders() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT f.id FROM public.folders f WHERE f.archived = TRUE
    UNION
    SELECT f.id FROM public.folders f WHERE f.organization_id IN (SELECT authz.archived_organizations())
    UNION
    SELECT fp.folder_id FROM public.folder_parents fp JOIN reached ON fp.parent_id = reached.id
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.archived_projects() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p.id FROM public.projects p WHERE p.archived = TRUE
  UNION
  SELECT p.id FROM public.projects p WHERE p.organization_id IN (SELECT authz.archived_organizations())
  UNION
  SELECT pf.project_id FROM public.project_folders pf WHERE pf.folder_id IN (SELECT authz.archived_folders())
$$;

CREATE FUNCTION authz.archived_ownables() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT o.id FROM public.ownables o WHERE o.archived = TRUE
  UNION
  SELECT o.id FROM public.ownables o WHERE o.project_id IN (SELECT authz.archived_projects())
$$;

CREATE FUNCTION authz.blocking_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT b.organization_id FROM public.organization_blocks b
  WHERE b.principal_id = current_setting('app.user_id', true)::uuid
    AND (b.expires_at IS NULL OR b.expires_at > now())
$$;

CREATE FUNCTION authz.blocked_projects() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p.id FROM public.projects p WHERE p.organization_id IN (SELECT authz.blocking_organizations())
$$;

CREATE FUNCTION authz.blocked_folders() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT f.id FROM public.folders f WHERE f.organization_id IN (SELECT authz.blocking_organizations())
$$;

CREATE FUNCTION authz.blocked_ownables() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT o.id FROM public.ownables o WHERE o.project_id IN (SELECT authz.blocked_projects())
$$;

CREATE FUNCTION authz.blocked_installations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT ai.id FROM public.app_installations ai WHERE ai.organization_id IN (SELECT authz.blocking_organizations())
$$;

CREATE FUNCTION authz.installations_allowing(target TEXT, command TEXT) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT ip.installation_id FROM public.installation_permissions ip
  WHERE ip.table_name = target AND ip.action = command
$$;

ALTER FUNCTION authz.caller_grantees() OWNER TO authz_owner;
ALTER FUNCTION authz.organizations_with(TEXT) OWNER TO authz_owner;
ALTER FUNCTION authz.folders_with(TEXT) OWNER TO authz_owner;
ALTER FUNCTION authz.projects_with(TEXT) OWNER TO authz_owner;
ALTER FUNCTION authz.ownables_with(TEXT) OWNER TO authz_owner;
ALTER FUNCTION authz.member_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.co_member_users() OWNER TO authz_owner;
ALTER FUNCTION authz.administered_teams() OWNER TO authz_owner;
ALTER FUNCTION authz.administered_installations() OWNER TO authz_owner;
ALTER FUNCTION authz.writers_share_folders() OWNER TO authz_owner;
ALTER FUNCTION authz.writers_share_projects() OWNER TO authz_owner;
ALTER FUNCTION authz.writers_share_ownables() OWNER TO authz_owner;
ALTER FUNCTION authz.archived_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.archived_folders() OWNER TO authz_owner;
ALTER FUNCTION authz.archived_projects() OWNER TO authz_owner;
ALTER FUNCTION authz.archived_ownables() OWNER TO authz_owner;
ALTER FUNCTION authz.blocking_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.blocked_projects() OWNER TO authz_owner;
ALTER FUNCTION authz.blocked_folders() OWNER TO authz_owner;
ALTER FUNCTION authz.blocked_ownables() OWNER TO authz_owner;
ALTER FUNCTION authz.blocked_installations() OWNER TO authz_owner;
ALTER FUNCTION authz.installations_allowing(TEXT, TEXT) OWNER TO authz_owner;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA authz FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authz TO app, authz_owner;
