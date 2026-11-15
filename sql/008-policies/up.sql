-- Privileges and policies per table. Restrictive policies cap installations, apply blocks and freeze archived rows.

-- Privileges count unless revoked, so every table starts from none.
REVOKE ALL ON grantees, users, platform_operators, organizations, memberships, invitations, teams, team_parents, team_members, folders, folder_parents, projects, project_folders, ownables, organization_grants, folder_grants, project_grants, ownable_grants, share_links, organization_blocks, apps, app_installations, installation_permissions, audit_events FROM PUBLIC, app, identity_writer;

-- Users read themselves and their co-members. The identity layer writes them.
GRANT SELECT ON users TO app;
GRANT SELECT, INSERT ON users TO identity_writer;
CREATE POLICY users_select ON users FOR SELECT TO app
  USING ((id = (SELECT current_setting('app.user_id', true)::uuid))
    OR (id = ANY (ARRAY(SELECT authz.co_member_users()))));
CREATE POLICY users_select_identity_writer ON users FOR SELECT TO identity_writer
  USING (TRUE);
CREATE POLICY users_insert_identity_writer ON users FOR INSERT TO identity_writer
  WITH CHECK (TRUE);

-- Organizations.
GRANT SELECT, UPDATE (archived), DELETE ON organizations TO app;
CREATE POLICY organizations_select ON organizations FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.organizations_with('reader'))));
CREATE POLICY organizations_update ON organizations FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organizations_delete ON organizations FOR DELETE TO app
  USING (id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

-- Memberships, read by every active member, managed by organization admins, left by the member.
GRANT SELECT, INSERT, UPDATE (state), DELETE ON memberships TO app;
CREATE POLICY memberships_select ON memberships FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (user_id = (SELECT current_setting('app.user_id', true)::uuid)));
CREATE POLICY memberships_insert ON memberships FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY memberships_update ON memberships FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY memberships_delete ON memberships FOR DELETE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (user_id = (SELECT current_setting('app.user_id', true)::uuid)));

-- Invitations, managed by organization admins and read by the invitee.
GRANT SELECT, INSERT, DELETE ON invitations TO app;
CREATE POLICY invitations_select ON invitations FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (email = (SELECT current_setting('app.verified_email', true))));
CREATE POLICY invitations_insert ON invitations FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND invited_by_id = (SELECT current_setting('app.user_id', true)::uuid));
CREATE POLICY invitations_delete ON invitations FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

-- Teams, read by active members and managed by organization admins.
GRANT SELECT, INSERT, DELETE ON teams TO app;
CREATE POLICY teams_select ON teams FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.member_organizations())));
CREATE POLICY teams_insert ON teams FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY teams_delete ON teams FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, UPDATE (parent_id), DELETE ON team_parents TO app;
CREATE POLICY team_parents_select ON team_parents FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.member_organizations())));
CREATE POLICY team_parents_insert ON team_parents FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY team_parents_update ON team_parents FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY team_parents_delete ON team_parents FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

-- Team members, managed by organization admins and by the team's own admins.
GRANT SELECT, INSERT, UPDATE (team_role), DELETE ON team_members TO app;
CREATE POLICY team_members_select ON team_members FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.member_organizations())));
CREATE POLICY team_members_insert ON team_members FOR INSERT TO app
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))));
CREATE POLICY team_members_update ON team_members FOR UPDATE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))))
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))));
CREATE POLICY team_members_delete ON team_members FOR DELETE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))));

-- Folders and projects. Creating one under a parent goes through a definer function.
GRANT SELECT, INSERT, UPDATE (archived, writers_can_share), DELETE ON folders TO app;
CREATE POLICY folders_select ON folders FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.folders_with('reader'))));
CREATE POLICY folders_insert ON folders FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY folders_update ON folders FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.folders_with('writer'))))
  WITH CHECK (id = ANY (ARRAY(SELECT authz.folders_with('writer'))));
CREATE POLICY folders_delete ON folders FOR DELETE TO app
  USING (id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
GRANT SELECT, INSERT, UPDATE (archived, writers_can_share), DELETE ON projects TO app;
CREATE POLICY projects_select ON projects FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.projects_with('reader'))));
CREATE POLICY projects_insert ON projects FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY projects_update ON projects FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.projects_with('writer'))))
  WITH CHECK (id = ANY (ARRAY(SELECT authz.projects_with('writer'))));
CREATE POLICY projects_delete ON projects FOR DELETE TO app
  USING (id = ANY (ARRAY(SELECT authz.projects_with('admin'))));

-- Moving a folder or project needs admin on the parent it leaves and on the parent it joins.
GRANT SELECT, INSERT, UPDATE (parent_id), DELETE ON folder_parents TO app;
CREATE POLICY folder_parents_select ON folder_parents FOR SELECT TO app
  USING (folder_id = ANY (ARRAY(SELECT authz.folders_with('reader'))));
CREATE POLICY folder_parents_insert ON folder_parents FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND parent_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
CREATE POLICY folder_parents_update ON folder_parents FOR UPDATE TO app
  USING (parent_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
  WITH CHECK (parent_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
CREATE POLICY folder_parents_delete ON folder_parents FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND parent_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
GRANT SELECT, INSERT, UPDATE (folder_id), DELETE ON project_folders TO app;
CREATE POLICY project_folders_select ON project_folders FOR SELECT TO app
  USING (project_id = ANY (ARRAY(SELECT authz.projects_with('reader'))));
CREATE POLICY project_folders_insert ON project_folders FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
CREATE POLICY project_folders_update ON project_folders FOR UPDATE TO app
  USING (folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
  WITH CHECK (folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));
CREATE POLICY project_folders_delete ON project_folders FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))));

-- Ownables. A trigger checks writer on the project an ownable moves to.
GRANT SELECT, INSERT, UPDATE (project_id, archived, writers_can_share), DELETE ON ownables TO app;
CREATE POLICY ownables_select ON ownables FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.ownables_with('reader'))));
CREATE POLICY ownables_insert ON ownables FOR INSERT TO app
  WITH CHECK (project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND created_by_id = (SELECT current_setting('app.user_id', true)::uuid));
CREATE POLICY ownables_update ON ownables FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.ownables_with('writer'))))
  WITH CHECK (id = ANY (ARRAY(SELECT authz.ownables_with('writer'))));
CREATE POLICY ownables_delete ON ownables FOR DELETE TO app
  USING (id = ANY (ARRAY(SELECT authz.ownables_with('admin'))));

-- Grants, written by share authority on the target up to the sharer's own role, read by it and by each grantee.
GRANT SELECT, INSERT, UPDATE (role, expires_at), DELETE ON organization_grants TO app;
CREATE POLICY organization_grants_select ON organization_grants FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (grantee_id = ANY (ARRAY(SELECT authz.caller_grantees()))));
CREATE POLICY organization_grants_insert ON organization_grants FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_grants_update ON organization_grants FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_grants_delete ON organization_grants FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, UPDATE (role, expires_at), DELETE ON folder_grants TO app;
CREATE POLICY folder_grants_select ON folder_grants FOR SELECT TO app
  USING ((folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
    OR (folder_id = ANY (ARRAY(SELECT authz.folders_with('writer'))) AND folder_id = ANY (ARRAY(SELECT authz.writers_share_folders())))
    OR (grantee_id = ANY (ARRAY(SELECT authz.caller_grantees()))));
CREATE POLICY folder_grants_insert ON folder_grants FOR INSERT TO app
  WITH CHECK ((folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
    OR (role IN ('reader', 'writer') AND folder_id = ANY (ARRAY(SELECT authz.folders_with('writer'))) AND folder_id = ANY (ARRAY(SELECT authz.writers_share_folders()))));
CREATE POLICY folder_grants_update ON folder_grants FOR UPDATE TO app
  USING ((folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
    OR (role IN ('reader', 'writer') AND folder_id = ANY (ARRAY(SELECT authz.folders_with('writer'))) AND folder_id = ANY (ARRAY(SELECT authz.writers_share_folders()))))
  WITH CHECK ((folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
    OR (role IN ('reader', 'writer') AND folder_id = ANY (ARRAY(SELECT authz.folders_with('writer'))) AND folder_id = ANY (ARRAY(SELECT authz.writers_share_folders()))));
CREATE POLICY folder_grants_delete ON folder_grants FOR DELETE TO app
  USING ((folder_id = ANY (ARRAY(SELECT authz.folders_with('admin'))))
    OR (role IN ('reader', 'writer') AND folder_id = ANY (ARRAY(SELECT authz.folders_with('writer'))) AND folder_id = ANY (ARRAY(SELECT authz.writers_share_folders()))));
GRANT SELECT, INSERT, UPDATE (role, expires_at), DELETE ON project_grants TO app;
CREATE POLICY project_grants_select ON project_grants FOR SELECT TO app
  USING ((project_id = ANY (ARRAY(SELECT authz.projects_with('admin'))))
    OR (project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND project_id = ANY (ARRAY(SELECT authz.writers_share_projects())))
    OR (grantee_id = ANY (ARRAY(SELECT authz.caller_grantees()))));
CREATE POLICY project_grants_insert ON project_grants FOR INSERT TO app
  WITH CHECK ((project_id = ANY (ARRAY(SELECT authz.projects_with('admin'))))
    OR (role IN ('reader', 'writer') AND project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND project_id = ANY (ARRAY(SELECT authz.writers_share_projects()))));
CREATE POLICY project_grants_update ON project_grants FOR UPDATE TO app
  USING ((project_id = ANY (ARRAY(SELECT authz.projects_with('admin'))))
    OR (role IN ('reader', 'writer') AND project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND project_id = ANY (ARRAY(SELECT authz.writers_share_projects()))))
  WITH CHECK ((project_id = ANY (ARRAY(SELECT authz.projects_with('admin'))))
    OR (role IN ('reader', 'writer') AND project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND project_id = ANY (ARRAY(SELECT authz.writers_share_projects()))));
CREATE POLICY project_grants_delete ON project_grants FOR DELETE TO app
  USING ((project_id = ANY (ARRAY(SELECT authz.projects_with('admin'))))
    OR (role IN ('reader', 'writer') AND project_id = ANY (ARRAY(SELECT authz.projects_with('writer'))) AND project_id = ANY (ARRAY(SELECT authz.writers_share_projects()))));
GRANT SELECT, INSERT, UPDATE (role, expires_at), DELETE ON ownable_grants TO app;
CREATE POLICY ownable_grants_select ON ownable_grants FOR SELECT TO app
  USING ((ownable_id = ANY (ARRAY(SELECT authz.ownables_with('admin'))))
    OR (ownable_id = ANY (ARRAY(SELECT authz.ownables_with('writer'))) AND ownable_id = ANY (ARRAY(SELECT authz.writers_share_ownables())))
    OR (grantee_id = ANY (ARRAY(SELECT authz.caller_grantees()))));
CREATE POLICY ownable_grants_insert ON ownable_grants FOR INSERT TO app
  WITH CHECK ((ownable_id = ANY (ARRAY(SELECT authz.ownables_with('admin'))))
    OR (role IN ('reader', 'writer') AND ownable_id = ANY (ARRAY(SELECT authz.ownables_with('writer'))) AND ownable_id = ANY (ARRAY(SELECT authz.writers_share_ownables()))));
CREATE POLICY ownable_grants_update ON ownable_grants FOR UPDATE TO app
  USING ((ownable_id = ANY (ARRAY(SELECT authz.ownables_with('admin'))))
    OR (role IN ('reader', 'writer') AND ownable_id = ANY (ARRAY(SELECT authz.ownables_with('writer'))) AND ownable_id = ANY (ARRAY(SELECT authz.writers_share_ownables()))))
  WITH CHECK ((ownable_id = ANY (ARRAY(SELECT authz.ownables_with('admin'))))
    OR (role IN ('reader', 'writer') AND ownable_id = ANY (ARRAY(SELECT authz.ownables_with('writer'))) AND ownable_id = ANY (ARRAY(SELECT authz.writers_share_ownables()))));
CREATE POLICY ownable_grants_delete ON ownable_grants FOR DELETE TO app
  USING ((ownable_id = ANY (ARRAY(SELECT authz.ownables_with('admin'))))
    OR (role IN ('reader', 'writer') AND ownable_id = ANY (ARRAY(SELECT authz.ownables_with('writer'))) AND ownable_id = ANY (ARRAY(SELECT authz.writers_share_ownables()))));

-- Share links, managed by their creator and by organization admins, revoked and never deleted.
GRANT SELECT, INSERT, UPDATE (revoked, expires_at) ON share_links TO app;
CREATE POLICY share_links_select ON share_links FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (created_by_id = (SELECT current_setting('app.user_id', true)::uuid)));
CREATE POLICY share_links_insert ON share_links FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.member_organizations())) AND created_by_id = (SELECT current_setting('app.user_id', true)::uuid));
CREATE POLICY share_links_update ON share_links FOR UPDATE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (created_by_id = (SELECT current_setting('app.user_id', true)::uuid)))
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (created_by_id = (SELECT current_setting('app.user_id', true)::uuid)));

-- Organization blocks.
GRANT SELECT, INSERT, UPDATE (expires_at), DELETE ON organization_blocks TO app;
CREATE POLICY organization_blocks_select ON organization_blocks FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_blocks_insert ON organization_blocks FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_blocks_update ON organization_blocks FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_blocks_delete ON organization_blocks FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

-- Apps, readable by everyone and managed by the owning organization's admins.
GRANT SELECT, INSERT, UPDATE (name), DELETE ON apps TO app;
CREATE POLICY apps_select ON apps FOR SELECT TO app
  USING (TRUE);
CREATE POLICY apps_insert ON apps FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY apps_update ON apps FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY apps_delete ON apps FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, DELETE ON app_installations TO app;
CREATE POLICY app_installations_select ON app_installations FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY app_installations_insert ON app_installations FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY app_installations_delete ON app_installations FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, DELETE ON installation_permissions TO app;
CREATE POLICY installation_permissions_select ON installation_permissions FOR SELECT TO app
  USING (installation_id = ANY (ARRAY(SELECT authz.administered_installations())));
CREATE POLICY installation_permissions_insert ON installation_permissions FOR INSERT TO app
  WITH CHECK (installation_id = ANY (ARRAY(SELECT authz.administered_installations())));
CREATE POLICY installation_permissions_delete ON installation_permissions FOR DELETE TO app
  USING (installation_id = ANY (ARRAY(SELECT authz.administered_installations())));

-- Audit events, read by organization admins and written only by definer triggers.
GRANT SELECT ON audit_events TO app;
CREATE POLICY audit_events_select ON audit_events FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

-- Archived rows are read-only. Restoring goes through a definer function.
CREATE POLICY organizations_archived_update ON organizations AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_organizations()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_organizations()))));
CREATE POLICY organizations_archived_delete ON organizations AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_organizations()))));
CREATE POLICY folders_archived_insert ON folders AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY folders_archived_update ON folders AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_folders()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY folders_archived_delete ON folders AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY folder_parents_archived_insert ON folder_parents AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (folder_id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY folder_parents_archived_update ON folder_parents AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (folder_id = ANY (ARRAY(SELECT authz.archived_folders()))))
  WITH CHECK (NOT (folder_id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY folder_parents_archived_delete ON folder_parents AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (folder_id = ANY (ARRAY(SELECT authz.archived_folders()))));
CREATE POLICY projects_archived_insert ON projects AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY projects_archived_update ON projects AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_projects()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY projects_archived_delete ON projects AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY project_folders_archived_insert ON project_folders AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (project_id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY project_folders_archived_update ON project_folders AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (project_id = ANY (ARRAY(SELECT authz.archived_projects()))))
  WITH CHECK (NOT (project_id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY project_folders_archived_delete ON project_folders AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (project_id = ANY (ARRAY(SELECT authz.archived_projects()))));
CREATE POLICY ownables_archived_insert ON ownables AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_ownables()))));
CREATE POLICY ownables_archived_update ON ownables AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_ownables()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.archived_ownables()))));
CREATE POLICY ownables_archived_delete ON ownables AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.archived_ownables()))));

-- A block removes everything inside the organization from the blocked principal.
CREATE POLICY organizations_blocked ON organizations AS RESTRICTIVE FOR ALL TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY memberships_blocked ON memberships AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY invitations_blocked ON invitations AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY teams_blocked ON teams AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY team_parents_blocked ON team_parents AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY team_members_blocked ON team_members AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY folders_blocked ON folders AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY projects_blocked ON projects AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY folder_parents_blocked ON folder_parents AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY project_folders_blocked ON project_folders AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY ownables_blocked ON ownables AS RESTRICTIVE FOR ALL TO app
  USING (NOT (id = ANY (ARRAY(SELECT authz.blocked_ownables()))))
  WITH CHECK (NOT (id = ANY (ARRAY(SELECT authz.blocked_ownables()))));
CREATE POLICY organization_grants_blocked ON organization_grants AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY folder_grants_blocked ON folder_grants AS RESTRICTIVE FOR ALL TO app
  USING (NOT (folder_id = ANY (ARRAY(SELECT authz.blocked_folders()))))
  WITH CHECK (NOT (folder_id = ANY (ARRAY(SELECT authz.blocked_folders()))));
CREATE POLICY project_grants_blocked ON project_grants AS RESTRICTIVE FOR ALL TO app
  USING (NOT (project_id = ANY (ARRAY(SELECT authz.blocked_projects()))))
  WITH CHECK (NOT (project_id = ANY (ARRAY(SELECT authz.blocked_projects()))));
CREATE POLICY ownable_grants_blocked ON ownable_grants AS RESTRICTIVE FOR ALL TO app
  USING (NOT (ownable_id = ANY (ARRAY(SELECT authz.blocked_ownables()))))
  WITH CHECK (NOT (ownable_id = ANY (ARRAY(SELECT authz.blocked_ownables()))));
CREATE POLICY share_links_blocked ON share_links AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY organization_blocks_blocked ON organization_blocks AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY app_installations_blocked ON app_installations AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY installation_permissions_blocked ON installation_permissions AS RESTRICTIVE FOR ALL TO app
  USING (NOT (installation_id = ANY (ARRAY(SELECT authz.blocked_installations()))))
  WITH CHECK (NOT (installation_id = ANY (ARRAY(SELECT authz.blocked_installations()))));
CREATE POLICY audit_events_blocked ON audit_events AS RESTRICTIVE FOR SELECT TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));

-- Acting on behalf of a user, an installation reaches only the tables and commands it was approved for.
CREATE POLICY users_installation_select ON users AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('users', 'select')));
CREATE POLICY organizations_installation_select ON organizations AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organizations', 'select')));
CREATE POLICY organizations_installation_update ON organizations AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organizations', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organizations', 'update')));
CREATE POLICY organizations_installation_delete ON organizations AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organizations', 'delete')));
CREATE POLICY memberships_installation_select ON memberships AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('memberships', 'select')));
CREATE POLICY memberships_installation_insert ON memberships AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('memberships', 'insert')));
CREATE POLICY memberships_installation_update ON memberships AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('memberships', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('memberships', 'update')));
CREATE POLICY memberships_installation_delete ON memberships AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('memberships', 'delete')));
CREATE POLICY invitations_installation_select ON invitations AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('invitations', 'select')));
CREATE POLICY invitations_installation_insert ON invitations AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('invitations', 'insert')));
CREATE POLICY invitations_installation_delete ON invitations AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('invitations', 'delete')));
CREATE POLICY teams_installation_select ON teams AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('teams', 'select')));
CREATE POLICY teams_installation_insert ON teams AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('teams', 'insert')));
CREATE POLICY teams_installation_delete ON teams AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('teams', 'delete')));
CREATE POLICY team_parents_installation_select ON team_parents AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_parents', 'select')));
CREATE POLICY team_parents_installation_insert ON team_parents AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_parents', 'insert')));
CREATE POLICY team_parents_installation_update ON team_parents AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_parents', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_parents', 'update')));
CREATE POLICY team_parents_installation_delete ON team_parents AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_parents', 'delete')));
CREATE POLICY team_members_installation_select ON team_members AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_members', 'select')));
CREATE POLICY team_members_installation_insert ON team_members AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_members', 'insert')));
CREATE POLICY team_members_installation_update ON team_members AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_members', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_members', 'update')));
CREATE POLICY team_members_installation_delete ON team_members AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('team_members', 'delete')));
CREATE POLICY folders_installation_select ON folders AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folders', 'select')));
CREATE POLICY folders_installation_insert ON folders AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folders', 'insert')));
CREATE POLICY folders_installation_update ON folders AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folders', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folders', 'update')));
CREATE POLICY folders_installation_delete ON folders AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folders', 'delete')));
CREATE POLICY projects_installation_select ON projects AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('projects', 'select')));
CREATE POLICY projects_installation_insert ON projects AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('projects', 'insert')));
CREATE POLICY projects_installation_update ON projects AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('projects', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('projects', 'update')));
CREATE POLICY projects_installation_delete ON projects AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('projects', 'delete')));
CREATE POLICY folder_parents_installation_select ON folder_parents AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_parents', 'select')));
CREATE POLICY folder_parents_installation_insert ON folder_parents AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_parents', 'insert')));
CREATE POLICY folder_parents_installation_update ON folder_parents AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_parents', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_parents', 'update')));
CREATE POLICY folder_parents_installation_delete ON folder_parents AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_parents', 'delete')));
CREATE POLICY project_folders_installation_select ON project_folders AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_folders', 'select')));
CREATE POLICY project_folders_installation_insert ON project_folders AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_folders', 'insert')));
CREATE POLICY project_folders_installation_update ON project_folders AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_folders', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_folders', 'update')));
CREATE POLICY project_folders_installation_delete ON project_folders AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_folders', 'delete')));
CREATE POLICY ownables_installation_select ON ownables AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownables', 'select')));
CREATE POLICY ownables_installation_insert ON ownables AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownables', 'insert')));
CREATE POLICY ownables_installation_update ON ownables AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownables', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownables', 'update')));
CREATE POLICY ownables_installation_delete ON ownables AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownables', 'delete')));
CREATE POLICY organization_grants_installation_select ON organization_grants AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_grants', 'select')));
CREATE POLICY organization_grants_installation_insert ON organization_grants AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_grants', 'insert')));
CREATE POLICY organization_grants_installation_update ON organization_grants AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_grants', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_grants', 'update')));
CREATE POLICY organization_grants_installation_delete ON organization_grants AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_grants', 'delete')));
CREATE POLICY folder_grants_installation_select ON folder_grants AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_grants', 'select')));
CREATE POLICY folder_grants_installation_insert ON folder_grants AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_grants', 'insert')));
CREATE POLICY folder_grants_installation_update ON folder_grants AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_grants', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_grants', 'update')));
CREATE POLICY folder_grants_installation_delete ON folder_grants AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('folder_grants', 'delete')));
CREATE POLICY project_grants_installation_select ON project_grants AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_grants', 'select')));
CREATE POLICY project_grants_installation_insert ON project_grants AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_grants', 'insert')));
CREATE POLICY project_grants_installation_update ON project_grants AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_grants', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_grants', 'update')));
CREATE POLICY project_grants_installation_delete ON project_grants AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('project_grants', 'delete')));
CREATE POLICY ownable_grants_installation_select ON ownable_grants AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownable_grants', 'select')));
CREATE POLICY ownable_grants_installation_insert ON ownable_grants AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownable_grants', 'insert')));
CREATE POLICY ownable_grants_installation_update ON ownable_grants AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownable_grants', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownable_grants', 'update')));
CREATE POLICY ownable_grants_installation_delete ON ownable_grants AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('ownable_grants', 'delete')));
CREATE POLICY share_links_installation_select ON share_links AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('share_links', 'select')));
CREATE POLICY share_links_installation_insert ON share_links AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('share_links', 'insert')));
CREATE POLICY share_links_installation_update ON share_links AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('share_links', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('share_links', 'update')));
CREATE POLICY organization_blocks_installation_select ON organization_blocks AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_blocks', 'select')));
CREATE POLICY organization_blocks_installation_insert ON organization_blocks AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_blocks', 'insert')));
CREATE POLICY organization_blocks_installation_update ON organization_blocks AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_blocks', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_blocks', 'update')));
CREATE POLICY organization_blocks_installation_delete ON organization_blocks AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('organization_blocks', 'delete')));
CREATE POLICY apps_installation_select ON apps AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('apps', 'select')));
CREATE POLICY apps_installation_insert ON apps AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('apps', 'insert')));
CREATE POLICY apps_installation_update ON apps AS RESTRICTIVE FOR UPDATE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('apps', 'update')))
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('apps', 'update')));
CREATE POLICY apps_installation_delete ON apps AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('apps', 'delete')));
CREATE POLICY app_installations_installation_select ON app_installations AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('app_installations', 'select')));
CREATE POLICY app_installations_installation_insert ON app_installations AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('app_installations', 'insert')));
CREATE POLICY app_installations_installation_delete ON app_installations AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('app_installations', 'delete')));
CREATE POLICY installation_permissions_installation_select ON installation_permissions AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('installation_permissions', 'select')));
CREATE POLICY installation_permissions_installation_insert ON installation_permissions AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('installation_permissions', 'insert')));
CREATE POLICY installation_permissions_installation_delete ON installation_permissions AS RESTRICTIVE FOR DELETE TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('installation_permissions', 'delete')));
CREATE POLICY audit_events_installation_select ON audit_events AS RESTRICTIVE FOR SELECT TO app
  USING ((SELECT current_setting('app.installation_id', true)::uuid) = '00000000-0000-0000-0000-000000000000' OR (SELECT current_setting('app.installation_id', true)::uuid) IN (SELECT authz.installations_allowing('audit_events', 'select')));
