-- Grants on each level reach everything below their target until they expire.

CREATE TABLE organization_grants (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  grantee_id UUID NOT NULL REFERENCES grantees (id),
  role TEXT NOT NULL CHECK (role IN ('reader', 'writer', 'admin')),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (organization_id, grantee_id)
);
CREATE INDEX ON organization_grants (grantee_id);
ALTER TABLE organization_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_grants FORCE ROW LEVEL SECURITY;

CREATE TABLE folder_grants (
  folder_id UUID NOT NULL REFERENCES folders (id),
  grantee_id UUID NOT NULL REFERENCES grantees (id),
  role TEXT NOT NULL CHECK (role IN ('reader', 'writer', 'admin')),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (folder_id, grantee_id)
);
CREATE INDEX ON folder_grants (grantee_id);
ALTER TABLE folder_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE folder_grants FORCE ROW LEVEL SECURITY;

CREATE TABLE project_grants (
  project_id UUID NOT NULL REFERENCES projects (id),
  grantee_id UUID NOT NULL REFERENCES grantees (id),
  role TEXT NOT NULL CHECK (role IN ('reader', 'writer', 'admin')),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (project_id, grantee_id)
);
CREATE INDEX ON project_grants (grantee_id);
ALTER TABLE project_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_grants FORCE ROW LEVEL SECURITY;

CREATE TABLE ownable_grants (
  ownable_id UUID NOT NULL REFERENCES ownables (id),
  grantee_id UUID NOT NULL REFERENCES grantees (id),
  role TEXT NOT NULL CHECK (role IN ('reader', 'writer', 'admin')),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (ownable_id, grantee_id)
);
CREATE INDEX ON ownable_grants (grantee_id);
ALTER TABLE ownable_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE ownable_grants FORCE ROW LEVEL SECURITY;

-- The server binds the ids of links whose token hash a request presents to app.link_ids.
CREATE TABLE share_links (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'link' CHECK (kind = 'link'),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  token_hash BYTEA NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  expires_at TIMESTAMPTZ,
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_by_id UUID NOT NULL REFERENCES users (id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
CREATE INDEX ON share_links (organization_id);
CREATE INDEX ON share_links (created_by_id);
ALTER TABLE share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE share_links FORCE ROW LEVEL SECURITY;

-- A block removes every grant inside the organization from the blocked principal.
CREATE TABLE organization_blocks (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  principal_id UUID NOT NULL REFERENCES grantees (id),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (organization_id, principal_id)
);
CREATE INDEX ON organization_blocks (principal_id);
ALTER TABLE organization_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_blocks FORCE ROW LEVEL SECURITY;
