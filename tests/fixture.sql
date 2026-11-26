CREATE FUNCTION pg_temp.act(principal TEXT) RETURNS VOID LANGUAGE sql AS $$
  SELECT set_config('app.user_id', coalesce(principal, ''), false), set_config('app.installation_id', '', false),
         set_config('app.link_ids', '', false), set_config('app.original_actor_id', '', false),
         set_config('app.verified_email', '', false)
$$;
CREATE FUNCTION pg_temp.found_organization(organization UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.organizations (id, created_by_id) VALUES (organization, authz.caller_id());
  INSERT INTO public.resources (id, kind, organization_id) VALUES (organization, 'organization', organization);
  INSERT INTO public.memberships (organization_id, user_id, state) VALUES (organization, authz.caller_id(), 'active');
$$;
CREATE FUNCTION pg_temp.create_child_team(team UUID, parent UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.teams (id, organization_id, parent_id)
    SELECT team, ancestor.organization_id, parent FROM public.teams ancestor WHERE ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_child_resource(child UUID, child_kind authz.resource_kind, parent UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.resources (id, kind, organization_id, parent_id, parent_kind)
    SELECT child, child_kind, ancestor.organization_id, parent, ancestor.kind FROM public.resources ancestor WHERE ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_ownable(ownable UUID, organization UUID, project UUID, creator UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.resources (id, kind, organization_id, parent_id, parent_kind, created_by_id)
    VALUES (ownable, 'ownable', organization, project, 'project', creator);
$$;
CREATE FUNCTION pg_temp.accept_invitation(invitation UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.memberships (organization_id, user_id, state, invitation_id)
    SELECT pending.organization_id, authz.caller_id(), 'active', invitation FROM public.invitations pending WHERE pending.id = invitation;
$$;
-- The caller invites the member, who accepts, as an organization admin and the invitee do.
CREATE FUNCTION pg_temp.add_member(organization UUID, member UUID) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  inviter TEXT := current_setting('app.user_id');
  email TEXT := current_setting('app.verified_email');
  invitation UUID := gen_random_uuid();
BEGIN
  INSERT INTO public.invitations (id, organization_id, email, expires_at, invited_by_id)
    VALUES (invitation, organization, member || '@example.com', now() + interval '1 day', inviter::uuid);
  PERFORM set_config('app.user_id', member::text, false), set_config('app.verified_email', member || '@example.com', false);
  INSERT INTO public.memberships (organization_id, user_id, state, invitation_id) VALUES (organization, member, 'active', invitation);
  PERFORM set_config('app.user_id', inviter, false), set_config('app.verified_email', email, false);
END
$$;
GRANT EXECUTE ON FUNCTION pg_temp.found_organization(UUID), pg_temp.create_child_team(UUID, UUID),
  pg_temp.create_child_resource(UUID, authz.resource_kind, UUID), pg_temp.create_ownable(UUID, UUID, UUID, UUID),
  pg_temp.accept_invitation(UUID), pg_temp.add_member(UUID, UUID) TO app;
GRANT EXECUTE ON FUNCTION pg_temp.act(TEXT) TO app, identity_writer;
