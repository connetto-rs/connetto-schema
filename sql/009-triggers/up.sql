CREATE SCHEMA authz_write;
REVOKE ALL ON SCHEMA authz_write FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE authz_writer REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
GRANT USAGE ON SCHEMA authz_write TO authz_writer;
GRANT USAGE ON SCHEMA authz TO authz_writer;
GRANT EXECUTE ON FUNCTION authz.resources_with(authz.role), authz.sharable_grants(), authz.administered_teams(),
  authz.caller_id(), authz.acting_installation_id(), authz.original_actor_id(), authz.max_tree_depth() TO authz_writer;

GRANT INSERT, DELETE ON grantees TO authz_writer;
GRANT SELECT ON grantees, users, platform_operators TO authz_writer;
GRANT UPDATE (kind) ON users TO authz_writer;
GRANT SELECT ON organizations, teams, resources, grants TO authz_writer;
GRANT SELECT (id) ON share_links, app_installations TO authz_writer;
GRANT UPDATE (founded_at) ON organizations TO authz_writer;
GRANT SELECT ON memberships, invitations TO authz_writer;
GRANT UPDATE (accepted_by_id) ON invitations TO authz_writer;
GRANT INSERT ON audit_events, platform_audit_events TO authz_writer;
GRANT SELECT ON audit_events TO authz_writer;
GRANT DELETE ON grants TO authz_writer;
GRANT INSERT (organization_id, resource_id, grantee_id, grantee_kind, role) ON grants TO authz_writer;
GRANT DELETE ON resources TO authz_writer;

CREATE FUNCTION authz_write.require_support_expiry(target_user UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  -- A row version change makes stale snapshots fail serialization.
  UPDATE public.users SET kind = kind WHERE id = target_user;
  IF EXISTS (
    SELECT 1 FROM public.platform_operators operator
    JOIN public.grants permission ON permission.grantee_id = operator.id
    WHERE operator.id = target_user
      AND (permission.expires_at IS NULL OR NOT pg_catalog.isfinite(permission.expires_at))
  ) THEN
    RAISE EXCEPTION 'support grants require a finite expiry' USING ERRCODE = 'check_violation';
  END IF;
END
$$;

CREATE FUNCTION authz_write.check_grant_support_expiry() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM authz_write.require_support_expiry(NEW.grantee_id);
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.check_operator_support_expiry() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM authz_write.require_support_expiry(NEW.id);
  RETURN NEW;
END
$$;

CREATE TRIGGER grants_support_expiry AFTER INSERT ON grants
  FOR EACH ROW WHEN (NEW.grantee_kind = 'user' AND (NEW.expires_at IS NULL OR NOT isfinite(NEW.expires_at)))
  EXECUTE FUNCTION authz_write.check_grant_support_expiry();
CREATE TRIGGER grants_update_support_expiry AFTER UPDATE ON grants
  FOR EACH ROW WHEN (NEW.grantee_kind = 'user' AND (NEW.expires_at IS NULL OR NOT isfinite(NEW.expires_at))
    AND (OLD.grantee_id, OLD.grantee_kind, OLD.expires_at) IS DISTINCT FROM (NEW.grantee_id, NEW.grantee_kind, NEW.expires_at))
  EXECUTE FUNCTION authz_write.check_grant_support_expiry();
CREATE TRIGGER platform_operators_support_expiry AFTER INSERT ON platform_operators
  FOR EACH ROW EXECUTE FUNCTION authz_write.check_operator_support_expiry();
CREATE TRIGGER platform_operators_update_support_expiry AFTER UPDATE ON platform_operators
  FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.check_operator_support_expiry();

CREATE FUNCTION authz_write.insert_grantee() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  INSERT INTO public.grantees (id, kind) VALUES (NEW.id, NEW.kind)
    ON CONFLICT (id, kind) DO NOTHING;
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.delete_grantee() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  DELETE FROM public.grantees WHERE id = OLD.id;
  RETURN NULL;
END
$$;

CREATE TRIGGER users_grantee BEFORE INSERT ON users FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER users_grantee_removed AFTER DELETE ON users FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER users_grantee_rekeyed AFTER UPDATE ON users FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER organizations_grantee BEFORE INSERT ON organizations FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER organizations_grantee_removed AFTER DELETE ON organizations FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER organizations_grantee_rekeyed AFTER UPDATE ON organizations FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER teams_grantee BEFORE INSERT ON teams FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER teams_grantee_removed AFTER DELETE ON teams FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER teams_grantee_rekeyed AFTER UPDATE ON teams FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER share_links_grantee BEFORE INSERT ON share_links FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER share_links_grantee_removed AFTER DELETE ON share_links FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER share_links_grantee_rekeyed AFTER UPDATE ON share_links FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER app_installations_grantee BEFORE INSERT ON app_installations FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER app_installations_grantee_removed AFTER DELETE ON app_installations FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER app_installations_grantee_rekeyed AFTER UPDATE ON app_installations FOR EACH ROW WHEN (OLD.id IS DISTINCT FROM NEW.id) EXECUTE FUNCTION authz_write.delete_grantee();

CREATE FUNCTION authz_write.check_grantee_subtype() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.grantees grantee WHERE grantee.id = NEW.id AND grantee.kind = NEW.kind) AND NOT (CASE NEW.kind
    WHEN 'user' THEN EXISTS (SELECT 1 FROM public.users principal WHERE principal.id = NEW.id)
    WHEN 'organization' THEN EXISTS (SELECT 1 FROM public.organizations organization WHERE organization.id = NEW.id)
    WHEN 'team' THEN EXISTS (SELECT 1 FROM public.teams team WHERE team.id = NEW.id)
    WHEN 'link' THEN EXISTS (SELECT 1 FROM public.share_links link WHERE link.id = NEW.id)
    WHEN 'installation' THEN EXISTS (SELECT 1 FROM public.app_installations installation WHERE installation.id = NEW.id)
  END) THEN
    RAISE EXCEPTION 'grantee % requires its % row', NEW.id, NEW.kind USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER grantees_subtype_required AFTER INSERT OR UPDATE ON grantees
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN (NEW.kind IN ('user', 'organization', 'team', 'link', 'installation'))
  EXECUTE FUNCTION authz_write.check_grantee_subtype();

CREATE FUNCTION authz.stamp_archived_at() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.archived_at IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND OLD.archived_at IS NOT NULL THEN
      NEW.archived_at := OLD.archived_at;
    ELSE
      NEW.archived_at := now();
    END IF;
  END IF;
  RETURN NEW;
END
$$;

CREATE FUNCTION authz.stamp_revoked_at() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.revoked_at IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND OLD.revoked_at IS NOT NULL THEN
      NEW.revoked_at := OLD.revoked_at;
    ELSE
      NEW.revoked_at := now();
    END IF;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER resources_stamp_archived_at BEFORE INSERT OR UPDATE OF archived_at ON resources
  FOR EACH ROW EXECUTE FUNCTION authz.stamp_archived_at();
CREATE TRIGGER share_links_stamp_revoked_at BEFORE INSERT OR UPDATE OF revoked_at ON share_links
  FOR EACH ROW EXECUTE FUNCTION authz.stamp_revoked_at();
REVOKE EXECUTE ON FUNCTION authz.stamp_archived_at(), authz.stamp_revoked_at() FROM PUBLIC, app;

CREATE FUNCTION authz_write.copy_resource_archive() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  SELECT parent.kind, parent.archived INTO NEW.parent_kind, NEW.parent_archived
    FROM public.resources parent WHERE parent.id = NEW.parent_id;
  NEW.parent_archived := coalesce(NEW.parent_archived, FALSE);
  NEW.inherits_archive := NEW.parent_archived;
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.copy_grant_archive() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  NEW.resource_archived := coalesce((SELECT resource.archived FROM public.resources resource WHERE resource.id = NEW.resource_id), FALSE);
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.inherit_resource_archive() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  NEW.inherits_archive := NEW.parent_archived;
  RETURN NEW;
END
$$;

CREATE TRIGGER resources_copy_archive BEFORE INSERT ON resources
  FOR EACH ROW EXECUTE FUNCTION authz_write.copy_resource_archive();
CREATE TRIGGER resources_move_copy_archive BEFORE UPDATE ON resources
  FOR EACH ROW WHEN (OLD.parent_id IS DISTINCT FROM NEW.parent_id)
  EXECUTE FUNCTION authz_write.copy_resource_archive();
CREATE TRIGGER resources_update_inherit_archive BEFORE UPDATE OF parent_archived ON resources
  FOR EACH ROW WHEN (OLD.parent_archived IS DISTINCT FROM NEW.parent_archived)
  EXECUTE FUNCTION authz_write.inherit_resource_archive();
CREATE TRIGGER grants_copy_archive BEFORE INSERT ON grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.copy_grant_archive();
CREATE TRIGGER grants_move_copy_archive BEFORE UPDATE ON grants
  FOR EACH ROW WHEN (OLD.resource_id IS DISTINCT FROM NEW.resource_id)
  EXECUTE FUNCTION authz_write.copy_grant_archive();

CREATE FUNCTION authz_write.lock_organization(target_organization UUID) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM authz.refuse_repeatable_read();
  PERFORM organization.id FROM public.organizations organization
    WHERE organization.id = target_organization FOR NO KEY UPDATE;
  RETURN FOUND;
END
$$;

CREATE FUNCTION authz_write.check_team_parent() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  ancestor_depth INTEGER;
  descendant_depth INTEGER;
  contains_cycle BOOLEAN;
BEGIN
  PERFORM authz_write.lock_organization(NEW.organization_id);
  WITH RECURSIVE ancestors (id, depth) AS (
    SELECT NEW.parent_id, 1 WHERE NEW.parent_id IS NOT NULL
    UNION
    SELECT team.parent_id, ancestors.depth + 1 FROM public.teams team
    JOIN ancestors ON team.id = ancestors.id
    WHERE team.parent_id IS NOT NULL
      AND ancestors.depth <= authz.max_tree_depth() AND ancestors.id <> NEW.id
  )
  SELECT max(ancestors.depth), bool_or(ancestors.id = NEW.id)
    INTO ancestor_depth, contains_cycle FROM ancestors;
  IF contains_cycle THEN
    RAISE EXCEPTION 'team % would become its own ancestor', NEW.id USING ERRCODE = 'check_violation';
  END IF;
  WITH RECURSIVE descendants (id, depth) AS (
    SELECT NEW.id, 1
    UNION
    SELECT team.id, descendants.depth + 1 FROM public.teams team
    JOIN descendants ON team.parent_id = descendants.id
    WHERE descendants.depth <= authz.max_tree_depth()
  )
  SELECT max(descendants.depth) INTO descendant_depth FROM descendants;
  IF coalesce(ancestor_depth, 0) + descendant_depth > authz.max_tree_depth() THEN
    RAISE EXCEPTION 'team % would exceed depth %', NEW.id, authz.max_tree_depth() USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.check_resource_parent() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  ancestor_depth INTEGER;
  descendant_depth INTEGER;
  contains_cycle BOOLEAN;
BEGIN
  PERFORM authz_write.lock_organization(NEW.organization_id);
  WITH RECURSIVE ancestors (id, depth) AS (
    SELECT NEW.parent_id, 1
    UNION
    SELECT resource.parent_id, ancestors.depth + 1 FROM public.resources resource
    JOIN ancestors ON resource.id = ancestors.id
    WHERE resource.parent_id IS NOT NULL
      AND ancestors.depth <= authz.max_tree_depth() AND ancestors.id <> NEW.id
  )
  SELECT max(ancestors.depth) FILTER (WHERE ancestors.id <> NEW.organization_id), bool_or(ancestors.id = NEW.id)
    INTO ancestor_depth, contains_cycle FROM ancestors;
  IF contains_cycle THEN
    RAISE EXCEPTION 'resource % would become its own ancestor', NEW.id USING ERRCODE = 'check_violation';
  END IF;
  WITH RECURSIVE descendants (id, depth) AS (
    SELECT NEW.id, 1
    UNION
    SELECT resource.id, descendants.depth + 1 FROM public.resources resource
    JOIN descendants ON resource.parent_id = descendants.id
    WHERE resource.kind IN ('folder', 'project') AND descendants.depth <= authz.max_tree_depth()
  )
  SELECT max(descendants.depth) INTO descendant_depth FROM descendants;
  IF coalesce(ancestor_depth, 0) + descendant_depth > authz.max_tree_depth() THEN
    RAISE EXCEPTION 'resource % would exceed depth %', NEW.id, authz.max_tree_depth() USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER teams_shape BEFORE INSERT ON teams
  FOR EACH ROW EXECUTE FUNCTION authz_write.check_team_parent();
CREATE TRIGGER teams_update_shape BEFORE UPDATE ON teams
  FOR EACH ROW WHEN ((OLD.id, OLD.organization_id, OLD.parent_id) IS DISTINCT FROM (NEW.id, NEW.organization_id, NEW.parent_id))
  EXECUTE FUNCTION authz_write.check_team_parent();
CREATE TRIGGER resources_shape BEFORE INSERT ON resources
  FOR EACH ROW WHEN (NEW.kind IN ('folder', 'project'))
  EXECUTE FUNCTION authz_write.check_resource_parent();
CREATE TRIGGER resources_update_shape BEFORE UPDATE ON resources
  FOR EACH ROW WHEN (NEW.kind IN ('folder', 'project')
    AND (OLD.id, OLD.organization_id, OLD.kind, OLD.parent_id) IS DISTINCT FROM (NEW.id, NEW.organization_id, NEW.kind, NEW.parent_id))
  EXECUTE FUNCTION authz_write.check_resource_parent();

CREATE FUNCTION authz_write.has_active_admin(target_organization UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.grants permission
    JOIN public.memberships membership
      ON membership.organization_id = permission.organization_id AND membership.user_id = permission.grantee_id
    WHERE permission.resource_id = target_organization AND permission.organization_id = target_organization
      AND permission.role = 'admin' AND permission.expires_at IS NULL AND permission.grantee_kind = 'user'
      AND membership.state = 'active'
  )
$$;

CREATE FUNCTION authz_write.require_organization_admin(target_organization UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NOT authz_write.lock_organization(target_organization) THEN
    RETURN;
  END IF;
  IF NOT authz_write.has_active_admin(target_organization) THEN
    RAISE EXCEPTION 'organization % would lose its last admin', target_organization USING ERRCODE = 'check_violation';
  END IF;
END
$$;

CREATE FUNCTION authz_write.check_last_admin() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM authz_write.require_organization_admin(OLD.organization_id);
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER grants_last_admin AFTER UPDATE OR DELETE ON grants
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  WHEN (OLD.role = 'admin' AND OLD.expires_at IS NULL AND OLD.grantee_kind = 'user' AND OLD.resource_id = OLD.organization_id)
  EXECUTE FUNCTION authz_write.check_last_admin();

CREATE FUNCTION authz_write.check_membership_admin() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM authz_write.require_organization_admin(OLD.organization_id);
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER memberships_last_admin AFTER UPDATE OR DELETE ON memberships
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN (OLD.state = 'active')
  EXECUTE FUNCTION authz_write.check_membership_admin();

CREATE FUNCTION authz_write.check_founded() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ONLY public.organizations organization WHERE organization.id = NEW.id) THEN
    RETURN NULL;
  END IF;
  IF NOT authz_write.has_active_admin(NEW.id) THEN
    RAISE EXCEPTION 'organization % requires an active admin', NEW.id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organizations_admin_required AFTER INSERT ON organizations
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION authz_write.check_founded();

CREATE FUNCTION authz_write.check_organization_identifier() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.audit_events event WHERE event.organization_id = NEW.id) THEN
    RAISE EXCEPTION 'organization % was deleted and its identifier is retired', NEW.id USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organizations_identifier_retired AFTER INSERT ON organizations
  FOR EACH ROW EXECUTE FUNCTION authz_write.check_organization_identifier();

CREATE FUNCTION authz_write.stamp_founded_at() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  UPDATE public.organizations SET founded_at = now() WHERE id = NEW.organization_id AND founded_at IS NULL;
  RETURN NULL;
END
$$;

CREATE TRIGGER grants_founded AFTER INSERT ON grants
  FOR EACH ROW WHEN (NEW.resource_id = NEW.organization_id AND NEW.role = 'admin')
  EXECUTE FUNCTION authz_write.stamp_founded_at();

CREATE FUNCTION authz_write.grant_founder_admin() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  INSERT INTO public.grants (organization_id, resource_id, grantee_id, grantee_kind, role)
    SELECT organization.id, organization.id, NEW.user_id, 'user', 'admin'
    FROM public.organizations organization
    WHERE organization.id = NEW.organization_id AND organization.created_by_id = NEW.user_id
      AND organization.founded_at IS NULL;
  RETURN NULL;
END
$$;

CREATE TRIGGER memberships_founder_admin AFTER INSERT ON memberships
  FOR EACH ROW WHEN (NEW.invitation_id IS NULL) EXECUTE FUNCTION authz_write.grant_founder_admin();

CREATE FUNCTION authz_write.delete_membership_grants() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  DELETE FROM public.grants
    WHERE organization_id = OLD.organization_id AND grantee_id = OLD.user_id AND grantee_kind = 'user';
  RETURN NULL;
END
$$;

CREATE TRIGGER memberships_grants_removed AFTER DELETE ON memberships
  FOR EACH ROW EXECUTE FUNCTION authz_write.delete_membership_grants();

CREATE FUNCTION authz_write.accept_invitation() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  UPDATE public.invitations SET accepted_by_id = NEW.user_id WHERE id = NEW.invitation_id;
  RETURN NULL;
END
$$;

CREATE TRIGGER memberships_invitation_accepted AFTER INSERT ON memberships
  FOR EACH ROW WHEN (NEW.invitation_id IS NOT NULL) EXECUTE FUNCTION authz_write.accept_invitation();

CREATE FUNCTION authz_write.record_audit_event() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  changed RECORD;
BEGIN
  IF TG_OP = 'DELETE' THEN
    changed := OLD;
  ELSE
    changed := NEW;
  END IF;
  INSERT INTO public.audit_events
    (at, organization_id, actor_id, original_actor_id, installation_id, table_name, operation, old_row, new_row)
  VALUES (
    now(), changed.organization_id, authz.caller_id(), authz.original_actor_id(),
    authz.acting_installation_id(), TG_TABLE_NAME, TG_OP::authz.audit_operation,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN NULL;
END
$$;

CREATE FUNCTION authz_write.record_platform_audit_event() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  INSERT INTO public.platform_audit_events
    (at, actor_id, original_actor_id, installation_id, table_name, operation, old_row, new_row)
  VALUES (
    now(), authz.caller_id(), authz.original_actor_id(),
    authz.acting_installation_id(), TG_TABLE_NAME, TG_OP::authz.audit_operation,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN NULL;
END
$$;

CREATE TRIGGER memberships_audit AFTER INSERT OR DELETE ON memberships
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER memberships_update_audit AFTER UPDATE ON memberships
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER invitations_audit AFTER INSERT OR DELETE ON invitations
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER invitations_update_audit AFTER UPDATE ON invitations
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER team_members_audit AFTER INSERT OR DELETE ON team_members
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER team_members_update_audit AFTER UPDATE ON team_members
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER grants_audit AFTER INSERT OR DELETE ON grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER grants_update_audit AFTER UPDATE ON grants
  FOR EACH ROW WHEN (to_jsonb(OLD) - 'resource_archived' IS DISTINCT FROM to_jsonb(NEW) - 'resource_archived')
  EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER share_links_audit AFTER INSERT OR DELETE ON share_links
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER share_links_update_audit AFTER UPDATE ON share_links
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER organization_blocks_audit AFTER INSERT OR DELETE ON organization_blocks
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER organization_blocks_update_audit AFTER UPDATE ON organization_blocks
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER app_installations_audit AFTER INSERT OR DELETE ON app_installations
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER app_installations_update_audit AFTER UPDATE ON app_installations
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER installation_permissions_audit AFTER INSERT OR DELETE ON installation_permissions
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER installation_permissions_update_audit AFTER UPDATE ON installation_permissions
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER teams_audit AFTER INSERT OR DELETE ON teams
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER teams_update_audit AFTER UPDATE ON teams
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER resources_audit AFTER INSERT OR DELETE ON resources
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER resources_update_audit AFTER UPDATE ON resources
  FOR EACH ROW WHEN (to_jsonb(OLD) - ARRAY['parent_archived', 'inherits_archive', 'archived'] IS DISTINCT FROM to_jsonb(NEW) - ARRAY['parent_archived', 'inherits_archive', 'archived'])
  EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER apps_audit AFTER INSERT OR DELETE ON apps
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER apps_update_audit AFTER UPDATE ON apps
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER users_audit AFTER INSERT OR DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_platform_audit_event();
CREATE TRIGGER users_update_audit AFTER UPDATE ON users
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_platform_audit_event();
CREATE TRIGGER platform_operators_audit AFTER INSERT OR DELETE ON platform_operators
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_platform_audit_event();
CREATE TRIGGER platform_operators_update_audit AFTER UPDATE ON platform_operators
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_platform_audit_event();
CREATE TRIGGER organizations_audit AFTER INSERT OR DELETE ON organizations
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_platform_audit_event();
CREATE TRIGGER organizations_update_audit AFTER UPDATE ON organizations
  FOR EACH ROW WHEN (OLD IS DISTINCT FROM NEW) EXECUTE FUNCTION authz_write.record_platform_audit_event();

ALTER FUNCTION authz_write.require_support_expiry(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_grant_support_expiry() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_operator_support_expiry() OWNER TO authz_writer;
ALTER FUNCTION authz_write.insert_grantee() OWNER TO authz_writer;
ALTER FUNCTION authz_write.delete_grantee() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_grantee_subtype() OWNER TO authz_writer;
ALTER FUNCTION authz.stamp_archived_at() OWNER TO authz_writer;
ALTER FUNCTION authz.stamp_revoked_at() OWNER TO authz_writer;
ALTER FUNCTION authz_write.copy_resource_archive() OWNER TO authz_writer;
ALTER FUNCTION authz_write.copy_grant_archive() OWNER TO authz_writer;
ALTER FUNCTION authz_write.inherit_resource_archive() OWNER TO authz_writer;
ALTER FUNCTION authz_write.lock_organization(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_team_parent() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_resource_parent() OWNER TO authz_writer;
ALTER FUNCTION authz_write.has_active_admin(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.require_organization_admin(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_last_admin() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_membership_admin() OWNER TO authz_writer;
ALTER FUNCTION authz_write.delete_membership_grants() OWNER TO authz_writer;
ALTER FUNCTION authz_write.accept_invitation() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_founded() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_organization_identifier() OWNER TO authz_writer;
ALTER FUNCTION authz_write.stamp_founded_at() OWNER TO authz_writer;
ALTER FUNCTION authz_write.grant_founder_admin() OWNER TO authz_writer;
ALTER FUNCTION authz_write.record_audit_event() OWNER TO authz_writer;
ALTER FUNCTION authz_write.record_platform_audit_event() OWNER TO authz_writer;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA authz_write FROM PUBLIC, app;
