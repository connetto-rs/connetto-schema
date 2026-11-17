ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE authz_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

GRANT SELECT ON grantees, platform_operators, organizations, memberships, invitations, teams, team_members, team_parents,
  share_links, resources, resource_parents, ownables, grants, organization_blocks, installation_permissions TO authz_owner;

CREATE FUNCTION authz.caller_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE FUNCTION authz.acting_installation_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT NULLIF(current_setting('app.installation_id', true), '')::uuid
$$;

CREATE FUNCTION authz.original_actor_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT NULLIF(current_setting('app.original_actor_id', true), '')::uuid
$$;

CREATE FUNCTION authz.link_ids() RETURNS UUID[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT string_to_array(NULLIF(current_setting('app.link_ids', true), ''), ',')::uuid[]
$$;

CREATE FUNCTION authz.verified_email() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT lower(NULLIF(current_setting('app.verified_email', true), ''))
$$;

CREATE FUNCTION authz.max_tree_depth() RETURNS INTEGER
LANGUAGE sql IMMUTABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT 20
$$;

CREATE FUNCTION authz.caller_grantees() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT grantee.id FROM public.grantees grantee
    WHERE grantee.id = authz.caller_id() AND grantee.kind IN ('user', 'installation')
    UNION
    SELECT grantee.id FROM public.grantees grantee WHERE grantee.kind = 'everyone'
    UNION
    SELECT grantee.id FROM public.grantees grantee
    WHERE grantee.kind = 'signed_in' AND authz.caller_id() IS NOT NULL
    UNION
    SELECT membership.organization_id FROM public.memberships membership
    WHERE membership.user_id = authz.caller_id() AND membership.state = 'active'
    UNION
    SELECT member.team_id FROM public.team_members member
    JOIN public.memberships membership ON membership.organization_id = member.organization_id AND membership.user_id = member.user_id
    WHERE member.user_id = authz.caller_id() AND membership.state = 'active'
    UNION
    SELECT link.id FROM public.share_links link
    WHERE link.id = ANY (authz.link_ids())
      AND link.revoked_at IS NULL AND (link.expires_at IS NULL OR link.expires_at > now())
    UNION
    SELECT parent.parent_id FROM public.team_parents parent JOIN reached ON parent.id = reached.id
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.capped_kinds(min_role authz.role)
RETURNS TABLE (organization_id UUID, kind authz.resource_kind)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT permission.organization_id, permission.kind FROM public.installation_permissions permission
  WHERE permission.installation_id = authz.acting_installation_id()
    AND permission.max_role >= min_role
$$;

CREATE FUNCTION authz.resources_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT permission.resource_id FROM public.grants permission
    WHERE permission.grantee_id IN (SELECT authz.caller_grantees())
      AND permission.role >= min_role AND (permission.expires_at IS NULL OR permission.expires_at > now())
      AND NOT EXISTS (
        SELECT 1 FROM public.memberships membership
        WHERE membership.organization_id = permission.organization_id
          AND membership.user_id = permission.grantee_id AND membership.state = 'deactivated'
      )
    UNION
    SELECT child.id FROM reached CROSS JOIN LATERAL (
      SELECT parent.id FROM public.resource_parents parent WHERE parent.parent_id = reached.id
      UNION ALL
      SELECT ownable.id FROM public.ownables ownable WHERE ownable.project_id = reached.id
    ) child
  )
  SELECT resource.id FROM public.resources resource
  WHERE resource.id IN (SELECT id FROM reached)
    AND (authz.acting_installation_id() IS NULL
      OR (resource.organization_id, resource.kind) IN (SELECT * FROM authz.capped_kinds(min_role)))
$$;

CREATE FUNCTION authz.sharable_grants() RETURNS TABLE (resource_id UUID, role authz.role)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT resource.id, allowed.role
  FROM authz.resources_with('admin') resource(id)
  CROSS JOIN unnest(enum_range(NULL::authz.role)) allowed(role)
  UNION
  SELECT resource.id, allowed.role FROM public.resources resource
  CROSS JOIN (VALUES ('reader'::authz.role), ('writer'::authz.role)) allowed(role)
  WHERE resource.writers_can_share AND resource.id IN (SELECT authz.resources_with('writer'))
$$;

CREATE FUNCTION authz.member_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT membership.organization_id FROM public.memberships membership
  WHERE membership.user_id = authz.caller_id() AND membership.state = 'active'
    AND (authz.acting_installation_id() IS NULL
      OR (membership.organization_id, 'organization'::authz.resource_kind)
        IN (SELECT * FROM authz.capped_kinds('reader')))
$$;

CREATE FUNCTION authz.co_member_users() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT membership.user_id FROM public.memberships membership
  WHERE membership.organization_id IN (SELECT authz.member_organizations()) AND membership.state = 'active'
$$;

CREATE FUNCTION authz.administered_teams() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT member.team_id FROM public.team_members member
  JOIN public.memberships membership ON membership.organization_id = member.organization_id AND membership.user_id = member.user_id
  WHERE member.user_id = authz.caller_id()
    AND member.team_role = 'admin' AND membership.state = 'active'
    AND (authz.acting_installation_id() IS NULL
      OR (membership.organization_id, 'organization'::authz.resource_kind)
        IN (SELECT * FROM authz.capped_kinds('admin')))
$$;

CREATE FUNCTION authz.team_admin_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT team.organization_id FROM public.teams team WHERE team.id IN (SELECT authz.administered_teams())
$$;

CREATE FUNCTION authz.organizations_reaching(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT resource.organization_id FROM public.resources resource WHERE resource.id IN (SELECT authz.resources_with(min_role))
$$;

CREATE FUNCTION authz.organizations_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT resource.organization_id FROM public.resources resource
  WHERE resource.kind = 'organization' AND resource.id IN (SELECT authz.resources_with(min_role))
$$;

CREATE FUNCTION authz.founded_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT organization.id FROM public.organizations organization WHERE organization.created_by_id = authz.caller_id()
$$;

CREATE FUNCTION authz.pending_invitations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT invitation.id FROM public.invitations invitation
  WHERE invitation.email = authz.verified_email() AND invitation.accepted_by_id IS NULL AND invitation.expires_at > now()
$$;

CREATE FUNCTION authz.is_archived(resource UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH RECURSIVE ancestors (id) AS (
    SELECT resource
    UNION
    SELECT parent.id
    FROM ancestors CROSS JOIN LATERAL (
      SELECT edge.parent_id AS id FROM public.resource_parents edge WHERE edge.id = ancestors.id
      UNION ALL
      SELECT ownable.project_id FROM public.ownables ownable WHERE ownable.id = ancestors.id
    ) parent
  )
  SELECT EXISTS (
    SELECT 1 FROM ancestors
    JOIN public.resources ancestor ON ancestor.id = ancestors.id
    WHERE ancestor.archived_at IS NOT NULL
  )
$$;

CREATE FUNCTION authz.has_archived_ancestor(resource UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.resource_parents edge WHERE edge.id = resource AND authz.is_archived(edge.parent_id))
    OR EXISTS (SELECT 1 FROM public.ownables ownable WHERE ownable.id = resource AND authz.is_archived(ownable.project_id))
$$;

CREATE FUNCTION authz.blocking_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT block.organization_id FROM public.organization_blocks block
  WHERE block.principal_id IN (authz.caller_id(), authz.acting_installation_id())
    AND (block.expires_at IS NULL OR block.expires_at > now())
$$;

-- An installation never acts with its user's platform authority.
CREATE FUNCTION authz.is_platform_operator() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT authz.acting_installation_id() IS NULL
    AND EXISTS (SELECT 1 FROM public.platform_operators operator WHERE operator.id = authz.caller_id())
$$;

ALTER FUNCTION authz.caller_id() OWNER TO authz_owner;
ALTER FUNCTION authz.acting_installation_id() OWNER TO authz_owner;
ALTER FUNCTION authz.original_actor_id() OWNER TO authz_owner;
ALTER FUNCTION authz.link_ids() OWNER TO authz_owner;
ALTER FUNCTION authz.verified_email() OWNER TO authz_owner;
ALTER FUNCTION authz.max_tree_depth() OWNER TO authz_owner;
ALTER FUNCTION authz.caller_grantees() OWNER TO authz_owner;
ALTER FUNCTION authz.capped_kinds(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.resources_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.sharable_grants() OWNER TO authz_owner;
ALTER FUNCTION authz.member_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.co_member_users() OWNER TO authz_owner;
ALTER FUNCTION authz.administered_teams() OWNER TO authz_owner;
ALTER FUNCTION authz.team_admin_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.organizations_reaching(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.organizations_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.founded_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.pending_invitations() OWNER TO authz_owner;
ALTER FUNCTION authz.is_archived(UUID) OWNER TO authz_owner;
ALTER FUNCTION authz.has_archived_ancestor(UUID) OWNER TO authz_owner;
ALTER FUNCTION authz.blocking_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.is_platform_operator() OWNER TO authz_owner;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA authz FROM PUBLIC, app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authz TO app;
