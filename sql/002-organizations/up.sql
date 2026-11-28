CREATE TABLE organizations (
  namespace_id UUID NOT NULL,
  id UUID NOT NULL,
  kind authz.grantee_kind GENERATED ALWAYS AS ('organization') STORED NOT NULL,
  created_by_id UUID NOT NULL,
  -- The founder membership writes the admin grant that stamps `founded_at`.
  founded_at TIMESTAMPTZ,
  PRIMARY KEY (namespace_id, id),
  FOREIGN KEY (namespace_id, id, kind) REFERENCES grantees (namespace_id, id, kind) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (created_by_id) REFERENCES users (id)
);
CREATE INDEX ON organizations (created_by_id);
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;

CREATE TABLE invitations (
  id UUID PRIMARY KEY,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  email TEXT NOT NULL CHECK (email <> '' AND length(email) <= 320 AND email LIKE '%_@_%' AND email = lower(email)),
  expires_at TIMESTAMPTZ NOT NULL,
  invited_by_id UUID NOT NULL,
  accepted_by_id UUID,
  UNIQUE (organization_namespace_id, organization_id, id),
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (invited_by_id) REFERENCES users (id),
  FOREIGN KEY (accepted_by_id) REFERENCES users (id)
);
CREATE INDEX ON invitations (invited_by_id);
CREATE INDEX ON invitations (accepted_by_id);
CREATE INDEX ON invitations (email);
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations FORCE ROW LEVEL SECURITY;

CREATE TABLE memberships (
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL,
  state authz.membership_state NOT NULL,
  invitation_id UUID UNIQUE,
  PRIMARY KEY (organization_namespace_id, organization_id, user_id),
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (organization_namespace_id, organization_id, invitation_id)
    REFERENCES invitations (organization_namespace_id, organization_id, id) ON DELETE RESTRICT
);
CREATE INDEX ON memberships (user_id);
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships FORCE ROW LEVEL SECURITY;

CREATE TABLE teams (
  namespace_id UUID NOT NULL,
  id UUID NOT NULL,
  kind authz.grantee_kind GENERATED ALWAYS AS ('team') STORED NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  parent_namespace_id UUID,
  parent_id UUID,
  CHECK ((parent_namespace_id IS NULL) = (parent_id IS NULL)),
  CHECK ((parent_namespace_id, parent_id) <> (namespace_id, id)),
  PRIMARY KEY (namespace_id, id),
  UNIQUE (organization_namespace_id, organization_id, namespace_id, id),
  FOREIGN KEY (namespace_id, id, kind) REFERENCES grantees (namespace_id, id, kind) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (organization_namespace_id, organization_id, parent_namespace_id, parent_id)
    REFERENCES teams (organization_namespace_id, organization_id, namespace_id, id)
);
CREATE INDEX ON teams (parent_namespace_id, parent_id);
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams FORCE ROW LEVEL SECURITY;


CREATE TABLE team_members (
  team_namespace_id UUID NOT NULL,
  team_id UUID NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL,
  team_role authz.team_role NOT NULL,
  PRIMARY KEY (organization_namespace_id, organization_id, team_namespace_id, team_id, user_id),
  FOREIGN KEY (organization_namespace_id, organization_id, team_namespace_id, team_id)
    REFERENCES teams (organization_namespace_id, organization_id, namespace_id, id),
  FOREIGN KEY (organization_namespace_id, organization_id, user_id)
    REFERENCES memberships (organization_namespace_id, organization_id, user_id) ON DELETE CASCADE
);
CREATE INDEX ON team_members (user_id, organization_namespace_id, organization_id);
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members FORCE ROW LEVEL SECURITY;
