ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE authz_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

GRANT SELECT ON grantees, platform_operators, organizations, memberships, invitations, teams, team_members,
  share_links, resources, grants, organization_blocks, installation_permissions TO authz_owner;
GRANT SELECT ON namespaces TO authz_owner;

CREATE FUNCTION authz.caller_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE FUNCTION authz.caller_namespace() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT namespace.id FROM public.namespaces namespace
  WHERE namespace.user_id = (SELECT authz.caller_id())
$$;

CREATE FUNCTION authz.acting_installation_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT NULLIF(current_setting('app.installation_id', true), '')::uuid
$$;

CREATE FUNCTION authz.original_actor_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT NULLIF(current_setting('app.original_actor_id', true), '')::uuid
$$;

CREATE FUNCTION authz.link_ids() RETURNS UUID[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT string_to_array(NULLIF(current_setting('app.link_ids', true), ''), ',')::uuid[]
$$;

CREATE FUNCTION authz.verified_email() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT lower(NULLIF(current_setting('app.verified_email', true), ''))
$$;

CREATE FUNCTION authz.max_tree_depth() RETURNS INTEGER
LANGUAGE sql IMMUTABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT 20
$$;

CREATE FUNCTION authz.blocking_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT block.organization_id FROM public.organization_blocks block
  WHERE block.principal_id IN ((SELECT authz.caller_id()), (SELECT authz.acting_installation_id()))
    AND (block.expires_at IS NULL OR block.expires_at > now())
$$;

CREATE FUNCTION authz.capped_kinds(min_role authz.role)
RETURNS TABLE (organization_id UUID, kind authz.resource_kind)
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT permission.organization_id, permission.kind FROM public.installation_permissions permission
  WHERE permission.installation_id = (SELECT authz.acting_installation_id())
    AND permission.max_role >= min_role
    AND NOT (permission.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.member_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT membership.organization_id FROM public.memberships membership
  WHERE membership.user_id = (SELECT authz.caller_id()) AND membership.state = 'active'
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (membership.organization_id, 'organization'::authz.resource_kind)
        IN (SELECT * FROM authz.capped_kinds('reader')))
    AND NOT (membership.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.caller_grantees() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER ROWS 10 SET search_path = pg_catalog, pg_temp AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT grantee.id FROM public.grantees grantee
    WHERE grantee.id = (SELECT authz.caller_id()) AND grantee.kind IN ('user', 'installation')
    UNION
    SELECT grantee.id FROM public.grantees grantee WHERE grantee.kind = 'everyone'
    UNION
    SELECT grantee.id FROM public.grantees grantee
    WHERE grantee.kind = 'signed_in' AND (SELECT authz.caller_id()) IS NOT NULL
    UNION
    SELECT organization FROM authz.member_organizations() organization
    UNION
    SELECT member.team_id FROM public.team_members member
    WHERE member.user_id = (SELECT authz.caller_id()) AND member.organization_id IN (SELECT authz.member_organizations())
    UNION
    SELECT link.id FROM public.share_links link
    WHERE link.id = ANY (ARRAY(SELECT unnest(authz.link_ids())))
      AND link.revoked_at IS NULL AND (link.expires_at IS NULL OR link.expires_at > now())
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (link.organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))
      AND NOT (link.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
    UNION
    SELECT team.parent_id FROM public.teams team JOIN reached ON team.id = reached.id
    WHERE team.parent_id IS NOT NULL
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.granted_resources(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER ROWS 10 SET search_path = pg_catalog, pg_temp AS $$
  SELECT permission.resource_id FROM public.grants permission
  WHERE permission.grantee_id IN (SELECT authz.caller_grantees())
    AND permission.role >= min_role AND (permission.expires_at IS NULL OR permission.expires_at > now())
    AND NOT (permission.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (permission.organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))
    AND NOT EXISTS (
      SELECT 1 FROM public.memberships membership
      WHERE membership.organization_id = permission.organization_id
        AND membership.user_id = permission.grantee_id
        AND membership.state = 'deactivated'
    )
$$;

CREATE FUNCTION authz.containers_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER ROWS 10 SET search_path = pg_catalog, pg_temp AS $$
  WITH RECURSIVE reached (id) AS (
    SELECT granted.id FROM authz.granted_resources(min_role) granted (id)
    UNION
    SELECT child.id FROM reached JOIN public.resources child ON child.parent_id = reached.id
    WHERE child.kind IN ('folder', 'project')
  )
  SELECT id FROM reached
$$;

CREATE FUNCTION authz.reached_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT reached.id FROM authz.containers_with(min_role) reached (id)
  UNION
  SELECT child.id FROM public.resources child
  WHERE child.parent_id IN (SELECT authz.containers_with(min_role))
$$;

CREATE FUNCTION authz.resources_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.id FROM public.resources resource
  WHERE resource.id IN (SELECT authz.reached_with(min_role))
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (resource.organization_id, resource.kind) IN (SELECT * FROM authz.capped_kinds(min_role)))
    AND NOT (resource.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.residual_read_containers() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER ROWS 10 SET search_path = pg_catalog, pg_temp AS $$
  WITH RECURSIVE containers (id) AS (
    SELECT resource.id FROM public.resources resource
    WHERE resource.id IN (SELECT authz.granted_resources('reader'))
      AND resource.kind IN ('folder', 'project', 'ownable')
    UNION
    SELECT child.id FROM containers JOIN public.resources child ON child.parent_id = containers.id
    WHERE child.kind IN ('folder', 'project')
  )
  SELECT id FROM containers
$$;

CREATE FUNCTION authz.residual_read_reached() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT reached.id FROM authz.residual_read_containers() reached (id)
  UNION
  SELECT child.id FROM public.resources child
  WHERE child.parent_id IN (SELECT authz.residual_read_containers())
$$;

CREATE FUNCTION authz.residual_read_resources() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.id FROM public.resources resource
  WHERE resource.id IN (SELECT authz.residual_read_reached())
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (resource.organization_id, resource.kind) IN (SELECT * FROM authz.capped_kinds('reader')))
    AND NOT (resource.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.organization_resources_with(resource_kind authz.resource_kind) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.organization_id FROM public.resources resource
  WHERE resource.kind = 'organization'
    AND resource.id IN (SELECT authz.granted_resources('reader'))
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (resource.organization_id, resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))
$$;

CREATE FUNCTION authz.sharable_grants() RETURNS TABLE (resource_id UUID, role authz.role)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.id, allowed.role
  FROM authz.resources_with('admin') resource(id)
  CROSS JOIN unnest(enum_range(NULL::authz.role)) allowed(role)
  UNION
  SELECT resource.id, allowed.role FROM public.resources resource
  CROSS JOIN (VALUES ('reader'::authz.role), ('writer'::authz.role)) allowed(role)
  WHERE resource.writers_can_share AND resource.id IN (SELECT authz.resources_with('writer'))
    AND NOT (resource.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.sharable_resources() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT share.resource_id FROM authz.sharable_grants() share
$$;

CREATE FUNCTION authz.co_member_users() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT membership.user_id FROM public.memberships membership
  WHERE membership.organization_id IN (SELECT authz.member_organizations()) AND membership.state = 'active'
    AND NOT (membership.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.administered_teams() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT member.team_id FROM public.team_members member
  JOIN public.memberships membership ON membership.organization_id = member.organization_id AND membership.user_id = member.user_id
  WHERE member.user_id = (SELECT authz.caller_id())
    AND member.team_role = 'admin' AND membership.state = 'active'
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (membership.organization_id, 'organization'::authz.resource_kind)
        IN (SELECT * FROM authz.capped_kinds('admin')))
    AND NOT (member.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.team_admin_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT team.organization_id FROM public.teams team WHERE team.id IN (SELECT authz.administered_teams())
$$;

CREATE FUNCTION authz.organizations_reaching(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.organization_id FROM public.resources resource WHERE resource.id IN (SELECT authz.resources_with(min_role))
    AND NOT (resource.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.organizations_with(min_role authz.role) RETURNS SETOF UUID
LANGUAGE sql STABLE STRICT SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT resource.organization_id FROM public.resources resource
  WHERE resource.kind = 'organization' AND resource.id IN (SELECT authz.granted_resources(min_role))
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (resource.organization_id, resource.kind) IN (SELECT * FROM authz.capped_kinds(min_role)))
    AND NOT (resource.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.founded_organizations() RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT organization.id FROM public.organizations organization
  WHERE organization.created_by_id = (SELECT authz.caller_id()) AND organization.founded_at IS NULL
    AND (SELECT authz.acting_installation_id()) IS NULL
    AND NOT (organization.id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

CREATE FUNCTION authz.pending_invitations() RETURNS TABLE (organization_id UUID, id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT invitation.organization_id, invitation.id FROM public.invitations invitation
  WHERE invitation.email = (SELECT authz.verified_email()) AND invitation.accepted_by_id IS NULL AND invitation.expires_at > now()
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (invitation.organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))
    AND NOT (invitation.organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
$$;

-- An installation never acts with its user's platform authority.
CREATE FUNCTION authz.is_platform_operator() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.platform_operators operator
    WHERE operator.id = (SELECT authz.caller_id()) AND (SELECT authz.acting_installation_id()) IS NULL
  )
$$;

-- REPEATABLE READ keeps the snapshot taken before a row lock waited, so a check
-- run after the lock would still miss the write it waited for.
CREATE FUNCTION authz.refuse_repeatable_read() RETURNS VOID
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF pg_catalog.current_setting('transaction_isolation') = 'repeatable read' THEN
    RAISE EXCEPTION 'row-lock checks require read committed or serializable' USING ERRCODE = 'invalid_transaction_state';
  END IF;
END
$$;

ALTER FUNCTION authz.caller_id() OWNER TO authz_owner;
ALTER FUNCTION authz.caller_namespace() OWNER TO authz_owner;
ALTER FUNCTION authz.acting_installation_id() OWNER TO authz_owner;
ALTER FUNCTION authz.original_actor_id() OWNER TO authz_owner;
ALTER FUNCTION authz.link_ids() OWNER TO authz_owner;
ALTER FUNCTION authz.verified_email() OWNER TO authz_owner;
ALTER FUNCTION authz.max_tree_depth() OWNER TO authz_owner;
ALTER FUNCTION authz.caller_grantees() OWNER TO authz_owner;
ALTER FUNCTION authz.capped_kinds(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.granted_resources(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.containers_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.reached_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.resources_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.sharable_grants() OWNER TO authz_owner;
ALTER FUNCTION authz.sharable_resources() OWNER TO authz_owner;
ALTER FUNCTION authz.member_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.co_member_users() OWNER TO authz_owner;
ALTER FUNCTION authz.administered_teams() OWNER TO authz_owner;
ALTER FUNCTION authz.team_admin_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.organizations_reaching(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.organizations_with(authz.role) OWNER TO authz_owner;
ALTER FUNCTION authz.founded_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.pending_invitations() OWNER TO authz_owner;
ALTER FUNCTION authz.blocking_organizations() OWNER TO authz_owner;
ALTER FUNCTION authz.is_platform_operator() OWNER TO authz_owner;
ALTER FUNCTION authz.refuse_repeatable_read() OWNER TO authz_owner;
ALTER FUNCTION authz.residual_read_containers() OWNER TO authz_owner;
ALTER FUNCTION authz.residual_read_reached() OWNER TO authz_owner;
ALTER FUNCTION authz.residual_read_resources() OWNER TO authz_owner;
ALTER FUNCTION authz.organization_resources_with(authz.resource_kind) OWNER TO authz_owner;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA authz FROM PUBLIC, app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authz TO app;
-- The walk returns resources before the installation's kind cap applies, so only definer helpers call it.
REVOKE EXECUTE ON FUNCTION authz.containers_with(authz.role), authz.reached_with(authz.role) FROM app;
REVOKE EXECUTE ON FUNCTION authz.residual_read_containers(), authz.residual_read_reached() FROM app;
GRANT EXECUTE ON FUNCTION authz.refuse_repeatable_read() TO PUBLIC;
