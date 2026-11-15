-- Triggers and definer functions for the invariants and writes a policy cannot express.

CREATE SCHEMA authz_write;
REVOKE ALL ON SCHEMA authz_write FROM PUBLIC;
GRANT USAGE ON SCHEMA authz_write TO app, authz_writer;
GRANT USAGE ON SCHEMA authz TO authz_writer;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA authz TO authz_writer;

GRANT SELECT, INSERT, DELETE ON grantees TO authz_writer;
GRANT SELECT ON users, team_parents, folder_parents, folders, projects, ownables, app_installations, organization_grants TO authz_writer;
GRANT SELECT, INSERT ON organizations, memberships, teams, project_folders TO authz_writer;
GRANT INSERT ON organization_grants, team_parents, folder_parents, folders, projects, audit_events TO authz_writer;
GRANT SELECT, UPDATE (accepted_by_id) ON invitations TO authz_writer;
GRANT UPDATE (archived) ON organizations, folders, projects, ownables TO authz_writer;

-- A bound principal setting, or NULL when the connection bound the nil UUID.
CREATE FUNCTION authz_write.bound(setting TEXT) RETURNS UUID
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT NULLIF(NULLIF(current_setting(setting, true), ''), '00000000-0000-0000-0000-000000000000')::uuid
$$;

-- Refuses a definer write the acting installation was not approved for, as the installation cap does for direct writes.
CREATE FUNCTION authz_write.require_installation_allows(target TEXT, command TEXT) RETURNS VOID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF authz_write.bound('app.installation_id') IS NOT NULL
    AND authz_write.bound('app.installation_id') NOT IN (SELECT authz.installations_allowing(target, command)) THEN
    RAISE EXCEPTION 'installation % may not % on %', authz_write.bound('app.installation_id'), command, target
      USING ERRCODE = 'insufficient_privilege';
  END IF;
END
$$;

-- Refuses a definer write inside an organization that blocks the caller.
CREATE FUNCTION authz_write.require_unblocked(organization UUID) RETURNS VOID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF organization IN (SELECT authz.blocking_organizations()) THEN
    RAISE EXCEPTION 'organization % blocks the caller', organization USING ERRCODE = 'insufficient_privilege';
  END IF;
END
$$;

-- Each grantee kind writes its grantees row before its own row, and removes it after.
CREATE FUNCTION authz_write.insert_grantee() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.grantees (id, kind) VALUES (NEW.id, NEW.kind);
  RETURN NEW;
END
$$;

CREATE FUNCTION authz_write.delete_grantee() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.grantees g WHERE g.id = OLD.id;
  RETURN NULL;
END
$$;

CREATE TRIGGER users_grantee BEFORE INSERT ON users FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER users_grantee_removed AFTER DELETE ON users FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER organizations_grantee BEFORE INSERT ON organizations FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER organizations_grantee_removed AFTER DELETE ON organizations FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER teams_grantee BEFORE INSERT ON teams FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER teams_grantee_removed AFTER DELETE ON teams FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER share_links_grantee BEFORE INSERT ON share_links FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER share_links_grantee_removed AFTER DELETE ON share_links FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();
CREATE TRIGGER app_installations_grantee BEFORE INSERT ON app_installations FOR EACH ROW EXECUTE FUNCTION authz_write.insert_grantee();
CREATE TRIGGER app_installations_grantee_removed AFTER DELETE ON app_installations FOR EACH ROW EXECUTE FUNCTION authz_write.delete_grantee();

-- Refuses a team edge that closes a cycle or makes a chain longer than 20 teams.
CREATE FUNCTION authz_write.check_team_parent() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  above INTEGER;
  below INTEGER;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.organization_id::text, 0));
  IF EXISTS (
    WITH RECURSIVE up (id) AS (
      SELECT NEW.parent_id
      UNION
      SELECT tp.parent_id FROM public.team_parents tp JOIN up ON tp.team_id = up.id
    )
    SELECT 1 FROM up WHERE up.id = NEW.team_id
  ) THEN
    RAISE EXCEPTION 'team % would become its own ancestor', NEW.team_id USING ERRCODE = 'check_violation';
  END IF;
  WITH RECURSIVE up (id, depth) AS (
    SELECT NEW.parent_id, 1
    UNION ALL
    SELECT tp.parent_id, up.depth + 1 FROM public.team_parents tp JOIN up ON tp.team_id = up.id WHERE up.depth <= 20
  )
  SELECT max(up.depth) INTO above FROM up;
  WITH RECURSIVE down (id, depth) AS (
    SELECT NEW.team_id, 1
    UNION ALL
    SELECT tp.team_id, down.depth + 1 FROM public.team_parents tp JOIN down ON tp.parent_id = down.id WHERE down.depth <= 20
  )
  SELECT max(down.depth) INTO below FROM down;
  IF above + below > 20 THEN
    RAISE EXCEPTION 'team % would sit in a chain of % teams, over 20', NEW.team_id, above + below USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;

-- Refuses a folder edge that closes a cycle or makes a chain longer than 20 folders.
CREATE FUNCTION authz_write.check_folder_parent() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  above INTEGER;
  below INTEGER;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.organization_id::text, 0));
  IF EXISTS (
    WITH RECURSIVE up (id) AS (
      SELECT NEW.parent_id
      UNION
      SELECT fp.parent_id FROM public.folder_parents fp JOIN up ON fp.folder_id = up.id
    )
    SELECT 1 FROM up WHERE up.id = NEW.folder_id
  ) THEN
    RAISE EXCEPTION 'folder % would become its own ancestor', NEW.folder_id USING ERRCODE = 'check_violation';
  END IF;
  WITH RECURSIVE up (id, depth) AS (
    SELECT NEW.parent_id, 1
    UNION ALL
    SELECT fp.parent_id, up.depth + 1 FROM public.folder_parents fp JOIN up ON fp.folder_id = up.id WHERE up.depth <= 20
  )
  SELECT max(up.depth) INTO above FROM up;
  WITH RECURSIVE down (id, depth) AS (
    SELECT NEW.folder_id, 1
    UNION ALL
    SELECT fp.folder_id, down.depth + 1 FROM public.folder_parents fp JOIN down ON fp.parent_id = down.id WHERE down.depth <= 20
  )
  SELECT max(down.depth) INTO below FROM down;
  IF above + below > 20 THEN
    RAISE EXCEPTION 'folder % would sit in a chain of % folders, over 20', NEW.folder_id, above + below USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER team_parents_shape BEFORE INSERT OR UPDATE ON team_parents
  FOR EACH ROW EXECUTE FUNCTION authz_write.check_team_parent();
CREATE TRIGGER folder_parents_shape BEFORE INSERT OR UPDATE ON folder_parents
  FOR EACH ROW EXECUTE FUNCTION authz_write.check_folder_parent();

-- At commit, an organization that still exists keeps an unexpiring admin grant.
CREATE FUNCTION authz_write.check_last_admin() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.organizations o WHERE o.id = OLD.organization_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.organization_grants og
      WHERE og.organization_id = OLD.organization_id AND og.role = 'admin' AND og.expires_at IS NULL
    ) THEN
    RAISE EXCEPTION 'organization % would lose its last admin', OLD.organization_id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organization_grants_last_admin AFTER UPDATE OR DELETE ON organization_grants
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION authz_write.check_last_admin();

-- Moving an ownable needs admin on it and writer on a project of the same organization.
CREATE FUNCTION authz_write.check_ownable_move() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT OLD.id IN (SELECT authz.ownables_with('admin'))
    OR NOT NEW.project_id IN (SELECT authz.projects_with('writer'))
    OR (SELECT p.organization_id FROM public.projects p WHERE p.id = NEW.project_id)
      IS DISTINCT FROM (SELECT p.organization_id FROM public.projects p WHERE p.id = OLD.project_id) THEN
    RAISE EXCEPTION 'ownable % may not move to project %', OLD.id, NEW.project_id USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER ownables_move BEFORE UPDATE OF project_id ON ownables
  FOR EACH ROW WHEN (NEW.project_id IS DISTINCT FROM OLD.project_id) EXECUTE FUNCTION authz_write.check_ownable_move();

-- Records who changed a row, on whose behalf and through which installation.
CREATE FUNCTION authz_write.record_audit_event() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  changed JSONB := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  organization UUID;
BEGIN
  organization := CASE TG_TABLE_NAME
    WHEN 'folder_grants' THEN
      (SELECT f.organization_id FROM public.folders f WHERE f.id = (changed ->> 'folder_id')::uuid)
    WHEN 'project_grants' THEN
      (SELECT p.organization_id FROM public.projects p WHERE p.id = (changed ->> 'project_id')::uuid)
    WHEN 'ownable_grants' THEN
      (SELECT p.organization_id FROM public.ownables o JOIN public.projects p ON p.id = o.project_id
       WHERE o.id = (changed ->> 'ownable_id')::uuid)
    WHEN 'installation_permissions' THEN
      (SELECT ai.organization_id FROM public.app_installations ai WHERE ai.id = (changed ->> 'installation_id')::uuid)
    ELSE (changed ->> 'organization_id')::uuid
  END;
  INSERT INTO public.audit_events
    (at, organization_id, actor_id, original_actor_id, installation_id, table_name, operation, old, new)
  VALUES (
    now(), organization, authz_write.bound('app.user_id'), authz_write.bound('app.original_actor_id'),
    authz_write.bound('app.installation_id'), TG_TABLE_NAME, TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN NULL;
END
$$;

CREATE TRIGGER memberships_audit AFTER INSERT OR UPDATE OR DELETE ON memberships
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER invitations_audit AFTER INSERT OR UPDATE OR DELETE ON invitations
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER team_members_audit AFTER INSERT OR UPDATE OR DELETE ON team_members
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER organization_grants_audit AFTER INSERT OR UPDATE OR DELETE ON organization_grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER folder_grants_audit AFTER INSERT OR UPDATE OR DELETE ON folder_grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER project_grants_audit AFTER INSERT OR UPDATE OR DELETE ON project_grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER ownable_grants_audit AFTER INSERT OR UPDATE OR DELETE ON ownable_grants
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER share_links_audit AFTER INSERT OR UPDATE OR DELETE ON share_links
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER organization_blocks_audit AFTER INSERT OR UPDATE OR DELETE ON organization_blocks
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER app_installations_audit AFTER INSERT OR UPDATE OR DELETE ON app_installations
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();
CREATE TRIGGER installation_permissions_audit AFTER INSERT OR UPDATE OR DELETE ON installation_permissions
  FOR EACH ROW EXECUTE FUNCTION authz_write.record_audit_event();

-- Any signed-in user creates an organization and becomes its first admin and member.
CREATE FUNCTION authz_write.create_organization(organization UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  caller UUID := authz_write.bound('app.user_id');
BEGIN
  PERFORM authz_write.require_installation_allows('organizations', 'insert');
  IF caller IS NULL OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = caller) THEN
    RAISE EXCEPTION 'only a signed-in user creates an organization' USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO public.organizations (id) VALUES (organization);
  INSERT INTO public.memberships (organization_id, user_id, state) VALUES (organization, caller, 'active');
  INSERT INTO public.organization_grants (organization_id, grantee_id, role) VALUES (organization, caller, 'admin');
END
$$;

-- A team admin of the parent, or an organization admin, creates a child team.
CREATE FUNCTION authz_write.create_child_team(team UUID, parent UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  organization UUID := (SELECT t.organization_id FROM public.teams t WHERE t.id = parent);
BEGIN
  PERFORM authz_write.require_installation_allows('teams', 'insert');
  PERFORM authz_write.require_unblocked(organization);
  IF organization IS NULL OR NOT (
    parent IN (SELECT authz.administered_teams()) OR organization IN (SELECT authz.organizations_with('admin'))
  ) THEN
    RAISE EXCEPTION 'creating a team under % needs admin on it', parent USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO public.teams (id, organization_id) VALUES (team, organization);
  INSERT INTO public.team_parents (organization_id, team_id, parent_id) VALUES (organization, team, parent);
END
$$;

-- An admin of the parent folder creates a folder under it.
CREATE FUNCTION authz_write.create_child_folder(folder UUID, parent UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  organization UUID := (SELECT f.organization_id FROM public.folders f WHERE f.id = parent);
BEGIN
  PERFORM authz_write.require_installation_allows('folders', 'insert');
  PERFORM authz_write.require_unblocked(organization);
  IF organization IS NULL OR NOT parent IN (SELECT authz.folders_with('admin'))
    OR parent IN (SELECT authz.archived_folders()) THEN
    RAISE EXCEPTION 'creating a folder under % needs admin on it', parent USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO public.folders (id, organization_id) VALUES (folder, organization);
  INSERT INTO public.folder_parents (organization_id, folder_id, parent_id) VALUES (organization, folder, parent);
END
$$;

-- An admin of the folder creates a project in it.
CREATE FUNCTION authz_write.create_folder_project(project UUID, folder UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  organization UUID := (SELECT f.organization_id FROM public.folders f WHERE f.id = folder);
BEGIN
  PERFORM authz_write.require_installation_allows('projects', 'insert');
  PERFORM authz_write.require_unblocked(organization);
  IF organization IS NULL OR NOT folder IN (SELECT authz.folders_with('admin'))
    OR folder IN (SELECT authz.archived_folders()) THEN
    RAISE EXCEPTION 'creating a project in % needs admin on it', folder USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO public.projects (id, organization_id) VALUES (project, organization);
  INSERT INTO public.project_folders (organization_id, project_id, folder_id) VALUES (organization, project, folder);
END
$$;

-- The invitee whose verified address matches accepts a pending invitation and becomes an active member.
CREATE FUNCTION authz_write.accept_invitation(invitation UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  caller UUID := authz_write.bound('app.user_id');
  organization UUID := (
    SELECT i.organization_id FROM public.invitations i
    WHERE i.id = invitation AND i.accepted_by_id IS NULL AND i.expires_at > now()
      AND i.email = current_setting('app.verified_email', true)
  );
BEGIN
  PERFORM authz_write.require_installation_allows('memberships', 'insert');
  IF caller IS NULL OR organization IS NULL OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = caller) THEN
    RAISE EXCEPTION 'invitation % is not pending for the caller', invitation USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM authz_write.require_unblocked(organization);
  INSERT INTO public.memberships (organization_id, user_id, state) VALUES (organization, caller, 'active');
  UPDATE public.invitations SET accepted_by_id = caller WHERE id = invitation;
END
$$;

-- An admin restores an archived row, which the archived restriction keeps every direct write from doing.
CREATE FUNCTION authz_write.restore_organization(organization UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM authz_write.require_installation_allows('organizations', 'update');
  PERFORM authz_write.require_unblocked(organization);
  IF NOT organization IN (SELECT authz.organizations_with('admin')) THEN
    RAISE EXCEPTION 'restoring organization % needs admin on it', organization USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.organizations SET archived = FALSE WHERE id = organization;
END
$$;

CREATE FUNCTION authz_write.restore_folder(folder UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM authz_write.require_installation_allows('folders', 'update');
  PERFORM authz_write.require_unblocked((SELECT f.organization_id FROM public.folders f WHERE f.id = folder));
  IF NOT folder IN (SELECT authz.folders_with('admin')) THEN
    RAISE EXCEPTION 'restoring folder % needs admin on it', folder USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.folders SET archived = FALSE WHERE id = folder;
END
$$;

CREATE FUNCTION authz_write.restore_project(project UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM authz_write.require_installation_allows('projects', 'update');
  PERFORM authz_write.require_unblocked((SELECT p.organization_id FROM public.projects p WHERE p.id = project));
  IF NOT project IN (SELECT authz.projects_with('admin')) THEN
    RAISE EXCEPTION 'restoring project % needs admin on it', project USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.projects SET archived = FALSE WHERE id = project;
END
$$;

CREATE FUNCTION authz_write.restore_ownable(ownable UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM authz_write.require_installation_allows('ownables', 'update');
  IF ownable IN (SELECT authz.blocked_ownables()) OR NOT ownable IN (SELECT authz.ownables_with('admin')) THEN
    RAISE EXCEPTION 'restoring ownable % needs admin on it', ownable USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.ownables SET archived = FALSE WHERE id = ownable;
END
$$;

ALTER FUNCTION authz_write.bound(TEXT) OWNER TO authz_writer;
ALTER FUNCTION authz_write.require_installation_allows(TEXT, TEXT) OWNER TO authz_writer;
ALTER FUNCTION authz_write.require_unblocked(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.insert_grantee() OWNER TO authz_writer;
ALTER FUNCTION authz_write.delete_grantee() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_team_parent() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_folder_parent() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_last_admin() OWNER TO authz_writer;
ALTER FUNCTION authz_write.check_ownable_move() OWNER TO authz_writer;
ALTER FUNCTION authz_write.record_audit_event() OWNER TO authz_writer;
ALTER FUNCTION authz_write.create_organization(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.create_child_team(UUID, UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.create_child_folder(UUID, UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.create_folder_project(UUID, UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.accept_invitation(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.restore_organization(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.restore_folder(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.restore_project(UUID) OWNER TO authz_writer;
ALTER FUNCTION authz_write.restore_ownable(UUID) OWNER TO authz_writer;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA authz_write FROM PUBLIC;
GRANT EXECUTE ON FUNCTION authz_write.bound(TEXT), authz_write.require_installation_allows(TEXT, TEXT),
  authz_write.require_unblocked(UUID) TO authz_writer;
GRANT EXECUTE ON FUNCTION authz_write.create_organization(UUID), authz_write.create_child_team(UUID, UUID),
  authz_write.create_child_folder(UUID, UUID), authz_write.create_folder_project(UUID, UUID),
  authz_write.accept_invitation(UUID), authz_write.restore_organization(UUID), authz_write.restore_folder(UUID),
  authz_write.restore_project(UUID), authz_write.restore_ownable(UUID) TO app;
