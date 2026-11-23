REVOKE ALL ON grantees, users, platform_operators, organizations, memberships, invitations, teams, team_parents, team_members, resources, resource_parents, ownables, grants, share_links, organization_blocks, apps, app_installations, installation_permissions, audit_events, platform_audit_events FROM PUBLIC, app, identity_writer;

-- The replica runs authz.caller_grantees() itself, so the caller's own grantee rows reach it.
-- Every other grantee is readable with the user, team, organization, link or installation it stands for.
GRANT SELECT ON grantees TO app;
CREATE POLICY grantees_select ON grantees FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.caller_grantees()))
    OR (kind = 'user' AND id = ANY (ARRAY(SELECT person.id FROM users person)))
    OR (kind = 'team' AND id = ANY (ARRAY(SELECT team.id FROM teams team)))
    OR (kind = 'organization' AND id = ANY (ARRAY(SELECT organization.id FROM organizations organization)))
    OR (kind = 'link' AND id = ANY (ARRAY(SELECT link.id FROM share_links link)))
    OR (kind = 'installation' AND id = ANY (ARRAY(SELECT installation.id FROM app_installations installation))));

GRANT SELECT ON users TO app;
GRANT SELECT, INSERT ON users TO identity_writer;
CREATE POLICY users_select ON users FOR SELECT TO app
  USING (id = (SELECT authz.caller_id())
    OR id = ANY (ARRAY(SELECT authz.co_member_users())));
CREATE POLICY users_identity_select ON users FOR SELECT TO identity_writer
  USING (TRUE);
CREATE POLICY users_insert ON users FOR INSERT TO identity_writer
  WITH CHECK (TRUE);

GRANT SELECT, DELETE ON organizations TO app;
GRANT INSERT (id, created_by_id) ON organizations TO app;
CREATE POLICY organizations_select ON organizations FOR SELECT TO app
  USING ((id = ANY (ARRAY(SELECT authz.organizations_reaching('reader'))))
    OR (id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (id = ANY (ARRAY(SELECT authz.founded_organizations())) AND (SELECT authz.acting_installation_id()) IS NULL)
    OR (id = ANY (ARRAY(SELECT invitation.organization_id FROM invitations invitation
      WHERE invitation.accepted_by_id IS NULL AND invitation.expires_at > now()))));
CREATE POLICY organizations_delete ON organizations FOR DELETE TO app
  USING (id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organizations_insert ON organizations FOR INSERT TO app
  WITH CHECK (created_by_id = (SELECT authz.caller_id()) AND (SELECT authz.acting_installation_id()) IS NULL);

GRANT SELECT, INSERT, UPDATE (state), DELETE ON memberships TO app;
CREATE POLICY memberships_select ON memberships FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (user_id = (SELECT authz.caller_id())
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))));
-- Members join only by founding or by accepting an invitation.
CREATE POLICY memberships_insert ON memberships FOR INSERT TO app
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.founded_organizations()))
      AND user_id = (SELECT authz.caller_id()) AND state = 'active' AND invitation_id IS NULL
      AND (SELECT authz.acting_installation_id()) IS NULL)
    OR ((organization_id, invitation_id) IN (SELECT * FROM authz.pending_invitations())
      AND user_id = (SELECT authz.caller_id()) AND state = 'active'
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('writer')))));
CREATE POLICY memberships_update ON memberships FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY memberships_delete ON memberships FOR DELETE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (user_id = (SELECT authz.caller_id()) AND state = 'active'
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('writer')))));

GRANT SELECT, DELETE ON invitations TO app;
GRANT INSERT (id, organization_id, email, expires_at, invited_by_id) ON invitations TO app;
CREATE POLICY invitations_select ON invitations FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (email = (SELECT authz.verified_email())
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))));
CREATE POLICY invitations_insert ON invitations FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))) AND invited_by_id = (SELECT authz.caller_id()));
CREATE POLICY invitations_delete ON invitations FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

GRANT SELECT, INSERT, DELETE ON teams TO app;
CREATE POLICY teams_select ON teams FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))));
CREATE POLICY teams_insert ON teams FOR INSERT TO app
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (organization_id = ANY (ARRAY(SELECT authz.team_admin_organizations()))));
CREATE POLICY teams_delete ON teams FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, UPDATE (parent_id), DELETE ON team_parents TO app;
CREATE POLICY team_parents_select ON team_parents FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))));
CREATE POLICY team_parents_insert ON team_parents FOR INSERT TO app
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (parent_id = ANY (ARRAY(SELECT authz.administered_teams()))
      AND organization_id = ANY (ARRAY(SELECT authz.team_admin_organizations()))));
CREATE POLICY team_parents_update ON team_parents FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY team_parents_delete ON team_parents FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

GRANT SELECT, INSERT, UPDATE (team_role), DELETE ON team_members TO app;
CREATE POLICY team_members_select ON team_members FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.member_organizations())))
    OR (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))));
CREATE POLICY team_members_insert ON team_members FOR INSERT TO app
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))
      AND organization_id = ANY (ARRAY(SELECT authz.team_admin_organizations()))));
CREATE POLICY team_members_update ON team_members FOR UPDATE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))))
  WITH CHECK ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))));
CREATE POLICY team_members_delete ON team_members FOR DELETE TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (team_id = ANY (ARRAY(SELECT authz.administered_teams()))));

GRANT SELECT, INSERT (id, kind, organization_id, archived_at, writers_can_share), UPDATE (archived_at, writers_can_share), DELETE
  ON resources TO app;
CREATE POLICY resources_select ON resources FOR SELECT TO app
  USING ((id = ANY (ARRAY(SELECT authz.resources_with('reader'))))
    OR (organization_id = ANY (ARRAY(SELECT authz.founded_organizations()))
      AND (SELECT authz.acting_installation_id()) IS NULL));
CREATE POLICY resources_insert ON resources FOR INSERT TO app
  WITH CHECK ((kind IN ('folder', 'project')
      AND organization_id = ANY (ARRAY(SELECT authz.organizations_reaching('admin')))
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, kind) IN (SELECT * FROM authz.capped_kinds('admin'))))
    OR (kind = 'ownable'
      AND archived_at IS NULL AND writers_can_share = FALSE
      AND organization_id = ANY (ARRAY(SELECT authz.organizations_reaching('writer')))
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, kind) IN (SELECT * FROM authz.capped_kinds('writer'))))
    OR (kind = 'organization' AND organization_id = ANY (ARRAY(SELECT authz.founded_organizations()))
      AND (SELECT authz.acting_installation_id()) IS NULL));
CREATE POLICY resources_update ON resources FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.resources_with('admin'))))
  WITH CHECK (id = ANY (ARRAY(SELECT authz.resources_with('admin'))));
CREATE POLICY resources_delete ON resources FOR DELETE TO app
  USING ((kind IN ('organization', 'ownable') AND id = ANY (ARRAY(SELECT authz.resources_with('admin'))))
    OR (kind IN ('folder', 'project') AND id = ANY (ARRAY(SELECT authz.resources_with('admin')))
      AND organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))));

GRANT SELECT, INSERT (id, organization_id, resource_kind, parent_id, parent_kind), UPDATE (parent_id, parent_kind)
  ON resource_parents TO app;
CREATE POLICY resource_parents_select ON resource_parents FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.resources_with('reader'))));
CREATE POLICY resource_parents_insert ON resource_parents FOR INSERT TO app
  WITH CHECK (parent_id = ANY (ARRAY(SELECT authz.resources_with('admin'))));
CREATE POLICY resource_parents_update ON resource_parents FOR UPDATE TO app
  USING (parent_id = ANY (ARRAY(SELECT authz.resources_with('admin'))))
  WITH CHECK (parent_id = ANY (ARRAY(SELECT authz.resources_with('admin'))));

GRANT SELECT, INSERT (id, organization_id, project_id, created_by_id), UPDATE (project_id) ON ownables TO app;
CREATE POLICY ownables_select ON ownables FOR SELECT TO app
  USING (id = ANY (ARRAY(SELECT authz.resources_with('reader'))));
CREATE POLICY ownables_insert ON ownables FOR INSERT TO app
  WITH CHECK (project_id = ANY (ARRAY(SELECT authz.resources_with('writer')))
    AND created_by_id = (SELECT authz.caller_id())
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (organization_id, kind) IN (SELECT * FROM authz.capped_kinds('writer'))));
CREATE POLICY ownables_update ON ownables FOR UPDATE TO app
  USING (id = ANY (ARRAY(SELECT authz.resources_with('admin'))))
  WITH CHECK (project_id = ANY (ARRAY(SELECT authz.resources_with('writer'))));

GRANT SELECT, INSERT (resource_id, organization_id, grantee_id, grantee_kind, role, expires_at), UPDATE (role, expires_at), DELETE
  ON grants TO app;
CREATE POLICY grants_select ON grants FOR SELECT TO app
  USING (resource_id = ANY (ARRAY(SELECT authz.sharable_resources()))
    OR (grantee_id = ANY (ARRAY(SELECT authz.caller_grantees()))
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))));
CREATE POLICY grants_insert ON grants FOR INSERT TO app
  WITH CHECK ((grantee_id, grantee_kind) IN (SELECT grantee.id, grantee.kind FROM grantees grantee)
    AND ((resource_id, role) IN (SELECT share.resource_id, share.role FROM authz.sharable_grants() share)
      OR (resource_id = organization_id AND grantee_id = (SELECT authz.caller_id()) AND grantee_kind = 'user' AND role = 'admin'
        AND organization_id = ANY (ARRAY(SELECT authz.founded_organizations())) AND (SELECT authz.acting_installation_id()) IS NULL)));
CREATE POLICY grants_update ON grants FOR UPDATE TO app
  USING ((resource_id, role) IN (SELECT share.resource_id, share.role FROM authz.sharable_grants() share))
  WITH CHECK ((resource_id, role) IN (SELECT share.resource_id, share.role FROM authz.sharable_grants() share));
CREATE POLICY grants_delete ON grants FOR DELETE TO app
  USING ((resource_id, role) IN (SELECT share.resource_id, share.role FROM authz.sharable_grants() share));

GRANT SELECT, INSERT, UPDATE (revoked_at, expires_at), DELETE ON share_links TO app;
CREATE POLICY share_links_select ON share_links FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR (created_by_id = (SELECT authz.caller_id())
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('reader')))));
CREATE POLICY share_links_insert ON share_links FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.member_organizations())) AND created_by_id = (SELECT authz.caller_id())
    AND ((SELECT authz.acting_installation_id()) IS NULL
      OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('writer'))));
CREATE POLICY share_links_update ON share_links FOR UPDATE TO app
  USING (revoked_at IS NULL
    AND (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
      OR (created_by_id = (SELECT authz.caller_id())
        AND organization_id = ANY (ARRAY(SELECT authz.member_organizations()))
        AND ((SELECT authz.acting_installation_id()) IS NULL
          OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('writer'))))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
    OR (created_by_id = (SELECT authz.caller_id())
      AND organization_id = ANY (ARRAY(SELECT authz.member_organizations()))
      AND ((SELECT authz.acting_installation_id()) IS NULL
        OR (organization_id, 'organization'::authz.resource_kind) IN (SELECT * FROM authz.capped_kinds('writer')))));
CREATE POLICY share_links_delete ON share_links FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

GRANT SELECT, INSERT, UPDATE (expires_at), DELETE ON organization_blocks TO app;
CREATE POLICY organization_blocks_select ON organization_blocks FOR SELECT TO app
  USING ((organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
    OR principal_id = (SELECT authz.caller_id())
    OR principal_id = (SELECT authz.acting_installation_id()));
CREATE POLICY organization_blocks_insert ON organization_blocks FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
    AND (principal_id, principal_kind) IN (SELECT grantee.id, grantee.kind FROM grantees grantee));
CREATE POLICY organization_blocks_update ON organization_blocks FOR UPDATE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))))
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
CREATE POLICY organization_blocks_delete ON organization_blocks FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

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
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
    AND app_id IN (SELECT app.id FROM apps app));
CREATE POLICY app_installations_delete ON app_installations FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));
GRANT SELECT, INSERT, DELETE ON installation_permissions TO app;
CREATE POLICY installation_permissions_select ON installation_permissions FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
    OR installation_id = (SELECT authz.acting_installation_id()));
CREATE POLICY installation_permissions_insert ON installation_permissions FOR INSERT TO app
  WITH CHECK (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin')))
    AND (SELECT authz.acting_installation_id()) IS NULL);
CREATE POLICY installation_permissions_delete ON installation_permissions FOR DELETE TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

GRANT SELECT ON audit_events TO app;
CREATE POLICY audit_events_select ON audit_events FOR SELECT TO app
  USING (organization_id = ANY (ARRAY(SELECT authz.organizations_with('admin'))));

GRANT SELECT ON platform_operators TO app;
CREATE POLICY platform_operators_select ON platform_operators FOR SELECT TO app
  USING (id = (SELECT authz.caller_id()) AND (SELECT authz.acting_installation_id()) IS NULL);
GRANT SELECT ON platform_audit_events TO app;
CREATE POLICY platform_audit_events_select ON platform_audit_events FOR SELECT TO app
  USING ((SELECT authz.is_platform_operator()));

CREATE POLICY resources_archived_update ON resources AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT inherits_archive);
CREATE POLICY resources_archived_delete ON resources AS RESTRICTIVE FOR DELETE TO app
  USING (NOT archived);
CREATE POLICY ownables_archived_insert ON ownables AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT archived AND NOT project_archived);
CREATE POLICY ownables_archived_update ON ownables AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT archived)
  WITH CHECK (NOT archived AND NOT project_archived);
CREATE POLICY grants_archived_insert ON grants AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT resource_archived);
CREATE POLICY grants_archived_update ON grants AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT resource_archived)
  WITH CHECK (NOT resource_archived);
CREATE POLICY grants_archived_delete ON grants AS RESTRICTIVE FOR DELETE TO app
  USING (NOT resource_archived);
CREATE POLICY resource_parents_archived_insert ON resource_parents AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT archived AND NOT parent_archived);
CREATE POLICY resource_parents_archived_update ON resource_parents AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT archived)
  WITH CHECK (NOT archived AND NOT parent_archived);

CREATE POLICY resources_blocked ON resources AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY ownables_blocked ON ownables AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY grants_blocked ON grants AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
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
CREATE POLICY resource_parents_blocked ON resource_parents AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY share_links_blocked ON share_links AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
-- A blocked principal still reads its own blocks, and only an unblocked admin writes them.
CREATE POLICY organization_blocks_blocked_select ON organization_blocks AS RESTRICTIVE FOR SELECT TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations())))
    OR principal_id = (SELECT authz.caller_id())
    OR principal_id = (SELECT authz.acting_installation_id()));
CREATE POLICY organization_blocks_blocked_insert ON organization_blocks AS RESTRICTIVE FOR INSERT TO app
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY organization_blocks_blocked_update ON organization_blocks AS RESTRICTIVE FOR UPDATE TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY organization_blocks_blocked_delete ON organization_blocks AS RESTRICTIVE FOR DELETE TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY apps_blocked ON apps AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY app_installations_blocked ON app_installations AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY audit_events_blocked ON audit_events AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
CREATE POLICY installation_permissions_blocked ON installation_permissions AS RESTRICTIVE FOR ALL TO app
  USING (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))))
  WITH CHECK (NOT (organization_id = ANY (ARRAY(SELECT authz.blocking_organizations()))));
