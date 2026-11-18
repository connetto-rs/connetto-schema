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
GRANT EXECUTE ON FUNCTION pg_temp.act(TEXT) TO app, identity_writer;
