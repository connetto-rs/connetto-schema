CREATE FUNCTION pg_temp.act(principal TEXT) RETURNS VOID LANGUAGE sql AS $$
  SELECT set_config('app.user_id', coalesce(principal, ''), false), set_config('app.installation_namespace_id', '', false),
         set_config('app.installation_id', '', false), set_config('app.link_ids', '', false),
         set_config('app.original_actor_id', '', false), set_config('app.verified_email', '', false)
$$;
-- Provisions each user as the identity service does at sign-in, as identity_writer with the user as the session subject.
CREATE FUNCTION pg_temp.provision(VARIADIC principals UUID[]) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  principal UUID;
BEGIN
  FOREACH principal IN ARRAY principals LOOP
    PERFORM pg_temp.act(principal::text);
    SET ROLE identity_writer;
    INSERT INTO public.users (id) VALUES (principal);
    RESET ROLE;
  END LOOP;
  PERFORM pg_temp.act(NULL);
END
$$;
-- The namespace a user creates in, which the server generates and the namespaces policy hides from other callers.
CREATE FUNCTION pg_temp.namespace_of(principal UUID) RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT person.owned_namespace_id FROM public.users person WHERE person.id = principal
$$;
CREATE FUNCTION pg_temp.found_organization(organization_namespace UUID, organization UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.organizations (namespace_id, id, created_by_id) VALUES (organization_namespace, organization, authz.caller_id());
  INSERT INTO public.resources (id, kind, organization_namespace_id, organization_id)
    VALUES (organization, 'organization', organization_namespace, organization);
  INSERT INTO public.memberships (organization_namespace_id, organization_id, user_id, state)
    VALUES (organization_namespace, organization, authz.caller_id(), 'active');
$$;
CREATE FUNCTION pg_temp.create_child_team(team_namespace UUID, team UUID, parent_namespace UUID, parent UUID)
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.teams (namespace_id, id, organization_namespace_id, organization_id, parent_namespace_id, parent_id)
    SELECT team_namespace, team, ancestor.organization_namespace_id, ancestor.organization_id, parent_namespace, parent
    FROM public.teams ancestor WHERE ancestor.namespace_id = parent_namespace AND ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_child_resource(child UUID, child_kind authz.resource_kind, parent UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.resources (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind)
    SELECT child, child_kind, ancestor.organization_namespace_id, ancestor.organization_id, parent, ancestor.kind
    FROM public.resources ancestor WHERE ancestor.id = parent;
$$;
CREATE FUNCTION pg_temp.create_ownable(ownable UUID, organization_namespace UUID, organization UUID, project UUID, creator UUID)
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.resources
    (id, kind, organization_namespace_id, organization_id, parent_id, parent_kind, created_by_id)
    VALUES (ownable, 'ownable', organization_namespace, organization, project, 'project', creator);
$$;
CREATE FUNCTION pg_temp.accept_invitation(invitation UUID) RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO public.memberships (organization_namespace_id, organization_id, user_id, state, invitation_id)
    SELECT pending.organization_namespace_id, pending.organization_id, authz.caller_id(), 'active', invitation
    FROM public.invitations pending WHERE pending.id = invitation;
$$;
-- The caller invites the member, who accepts, as an organization admin and the invitee do.
CREATE FUNCTION pg_temp.add_member(organization_namespace UUID, organization UUID, member UUID) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  inviter TEXT := current_setting('app.user_id');
  email TEXT := current_setting('app.verified_email');
  invitation UUID := gen_random_uuid();
BEGIN
  INSERT INTO public.invitations (id, organization_namespace_id, organization_id, email, expires_at, invited_by_id)
    VALUES (invitation, organization_namespace, organization, member || '@example.com', now() + interval '1 day', inviter::uuid);
  PERFORM set_config('app.user_id', member::text, false), set_config('app.verified_email', member || '@example.com', false);
  INSERT INTO public.memberships (organization_namespace_id, organization_id, user_id, state, invitation_id)
    VALUES (organization_namespace, organization, member, 'active', invitation);
  PERFORM set_config('app.user_id', inviter, false), set_config('app.verified_email', email, false);
END
$$;
GRANT EXECUTE ON FUNCTION pg_temp.found_organization(UUID, UUID), pg_temp.create_child_team(UUID, UUID, UUID, UUID),
  pg_temp.create_child_resource(UUID, authz.resource_kind, UUID), pg_temp.create_ownable(UUID, UUID, UUID, UUID, UUID),
  pg_temp.accept_invitation(UUID), pg_temp.add_member(UUID, UUID, UUID) TO app;
GRANT EXECUTE ON FUNCTION pg_temp.act(TEXT), pg_temp.namespace_of(UUID) TO app, identity_writer;
