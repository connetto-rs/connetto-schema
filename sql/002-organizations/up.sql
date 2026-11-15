-- Organizations, their memberships and invitations, and the teams inside them.

-- An organization's id is also the grantee meaning its active members, as OpenFGA's organization#member.
CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'organization' CHECK (kind = 'organization'),
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;

-- A deactivated member keeps the row and loses every grant reached through membership and teams.
CREATE TABLE memberships (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  user_id UUID NOT NULL REFERENCES users (id),
  state TEXT NOT NULL CHECK (state IN ('active', 'deactivated')),
  PRIMARY KEY (organization_id, user_id),
  UNIQUE (organization_id, user_id, state)
);
CREATE INDEX ON memberships (user_id);
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships FORCE ROW LEVEL SECURITY;

-- Accepting one writes the membership. The identity layer binds app.verified_email for the address match.
CREATE TABLE invitations (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  email TEXT NOT NULL CHECK (email <> '' AND length(email) <= 320 AND email LIKE '%_@_%'),
  expires_at TIMESTAMPTZ NOT NULL,
  invited_by_id UUID NOT NULL REFERENCES users (id),
  accepted_by_id UUID REFERENCES users (id)
);
CREATE INDEX ON invitations (organization_id);
CREATE INDEX ON invitations (invited_by_id);
CREATE INDEX ON invitations (accepted_by_id);
CREATE INDEX ON invitations (email);
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations FORCE ROW LEVEL SECURITY;

CREATE TABLE teams (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'team' CHECK (kind = 'team'),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  UNIQUE (organization_id, id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams FORCE ROW LEVEL SECURITY;

-- A child team inherits its parent's grants. Its members are not members of the parent.
CREATE TABLE team_parents (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  team_id UUID NOT NULL REFERENCES teams (id),
  parent_id UUID NOT NULL REFERENCES teams (id) CHECK (parent_id <> team_id),
  PRIMARY KEY (organization_id, team_id),
  FOREIGN KEY (organization_id, team_id) REFERENCES teams (organization_id, id),
  FOREIGN KEY (organization_id, parent_id) REFERENCES teams (organization_id, id)
);
CREATE UNIQUE INDEX ON team_parents (team_id);
CREATE INDEX ON team_parents (organization_id, parent_id);
CREATE INDEX ON team_parents (parent_id);
ALTER TABLE team_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_parents FORCE ROW LEVEL SECURITY;

-- membership_state lets the caller's grantee set keep active members with a literal restriction.
CREATE TABLE team_members (
  team_id UUID NOT NULL REFERENCES teams (id),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  user_id UUID NOT NULL REFERENCES users (id),
  membership_state TEXT NOT NULL CHECK (membership_state IN ('active', 'deactivated')),
  team_role TEXT NOT NULL CHECK (team_role IN ('member', 'admin')),
  PRIMARY KEY (team_id, user_id),
  FOREIGN KEY (organization_id, team_id) REFERENCES teams (organization_id, id),
  FOREIGN KEY (organization_id, user_id, membership_state)
    REFERENCES memberships (organization_id, user_id, state) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX ON team_members (organization_id, team_id);
CREATE INDEX ON team_members (user_id);
CREATE INDEX ON team_members (organization_id, user_id, membership_state);
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members FORCE ROW LEVEL SECURITY;
