CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind NOT NULL DEFAULT 'organization' CHECK (kind = 'organization'),
  created_by_id UUID NOT NULL REFERENCES users (id),
  -- Set by the first admin grant on the organization. Its creator takes the founding membership and grant only while it is NULL.
  founded_at TIMESTAMPTZ,
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
CREATE INDEX ON organizations (created_by_id);
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;

CREATE TABLE invitations (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  email TEXT NOT NULL CHECK (email <> '' AND length(email) <= 320 AND email LIKE '%_@_%' AND email = lower(email)),
  expires_at TIMESTAMPTZ NOT NULL,
  invited_by_id UUID NOT NULL REFERENCES users (id),
  accepted_by_id UUID REFERENCES users (id),
  UNIQUE (organization_id, id)
);
CREATE INDEX ON invitations (invited_by_id);
CREATE INDEX ON invitations (accepted_by_id);
CREATE INDEX ON invitations (email);
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations FORCE ROW LEVEL SECURITY;

CREATE TABLE memberships (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  user_id UUID NOT NULL REFERENCES users (id),
  state authz.membership_state NOT NULL,
  invitation_id UUID UNIQUE,
  PRIMARY KEY (organization_id, user_id),
  FOREIGN KEY (organization_id, invitation_id) REFERENCES invitations (organization_id, id)
);
CREATE INDEX ON memberships (user_id);
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships FORCE ROW LEVEL SECURITY;

CREATE TABLE teams (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind NOT NULL DEFAULT 'team' CHECK (kind = 'team'),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  UNIQUE (organization_id, id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams FORCE ROW LEVEL SECURITY;

CREATE TABLE team_parents (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  parent_id UUID NOT NULL CHECK (parent_id <> id),
  FOREIGN KEY (organization_id, id) REFERENCES teams (organization_id, id),
  FOREIGN KEY (organization_id, parent_id) REFERENCES teams (organization_id, id)
);
CREATE INDEX ON team_parents (parent_id);
CREATE INDEX ON team_parents (organization_id);
ALTER TABLE team_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_parents FORCE ROW LEVEL SECURITY;

CREATE TABLE team_members (
  team_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL,
  team_role authz.team_role NOT NULL,
  PRIMARY KEY (team_id, user_id),
  FOREIGN KEY (organization_id, team_id) REFERENCES teams (organization_id, id),
  FOREIGN KEY (organization_id, user_id) REFERENCES memberships (organization_id, user_id) ON DELETE CASCADE
);
CREATE INDEX ON team_members (user_id, organization_id);
CREATE INDEX ON team_members (organization_id);
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members FORCE ROW LEVEL SECURITY;
