CREATE TABLE grants (
  resource_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  grantee_id UUID NOT NULL,
  grantee_kind authz.grantee_kind NOT NULL,
  role authz.role NOT NULL,
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (resource_id, grantee_id),
  FOREIGN KEY (organization_id, resource_id) REFERENCES resources (organization_id, id) ON DELETE CASCADE,
  FOREIGN KEY (grantee_id, grantee_kind) REFERENCES grantees (id, kind) ON DELETE CASCADE,
  CHECK (grantee_kind NOT IN ('everyone', 'signed_in', 'link') OR role < 'admin')
);
CREATE INDEX ON grants (grantee_id);
ALTER TABLE grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE grants FORCE ROW LEVEL SECURITY;

CREATE TABLE share_links (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind GENERATED ALWAYS AS ('link'::authz.grantee_kind) STORED NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  token_hash BYTEA NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_by_id UUID NOT NULL REFERENCES users (id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ON share_links (organization_id);
CREATE INDEX ON share_links (created_by_id);
ALTER TABLE share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE share_links FORCE ROW LEVEL SECURITY;

CREATE TABLE organization_blocks (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  principal_id UUID NOT NULL,
  principal_kind authz.grantee_kind NOT NULL CHECK (principal_kind IN ('user', 'installation')),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (organization_id, principal_id),
  FOREIGN KEY (principal_id, principal_kind) REFERENCES grantees (id, kind) ON DELETE CASCADE
);
CREATE INDEX ON organization_blocks (principal_id);
ALTER TABLE organization_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_blocks FORCE ROW LEVEL SECURITY;
