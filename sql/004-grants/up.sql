CREATE TABLE grants (
  resource_id UUID NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  grantee_namespace_id UUID NOT NULL,
  grantee_id UUID NOT NULL,
  grantee_kind authz.grantee_kind NOT NULL,
  role authz.role NOT NULL,
  expires_at TIMESTAMPTZ,
  resource_archived BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (resource_id, grantee_namespace_id, grantee_id),
  FOREIGN KEY (organization_namespace_id, organization_id, resource_id, resource_archived)
    REFERENCES resources (organization_namespace_id, organization_id, id, archived) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (grantee_namespace_id, grantee_id, grantee_kind) REFERENCES grantees (namespace_id, id, kind) ON DELETE CASCADE,
  CHECK (grantee_kind NOT IN ('everyone', 'signed_in', 'link') OR role < 'admin')
);
CREATE INDEX ON grants (grantee_namespace_id, grantee_id);
ALTER TABLE grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE grants FORCE ROW LEVEL SECURITY;

CREATE TABLE user_grants (
  resource_id UUID NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role authz.role NOT NULL,
  expires_at TIMESTAMPTZ,
  resource_archived BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (resource_id, user_id),
  FOREIGN KEY (organization_namespace_id, organization_id, resource_id, resource_archived)
    REFERENCES resources (organization_namespace_id, organization_id, id, archived) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX ON user_grants (user_id);
ALTER TABLE user_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_grants FORCE ROW LEVEL SECURITY;

CREATE TABLE share_links (
  namespace_id UUID NOT NULL,
  id UUID NOT NULL,
  kind authz.grantee_kind GENERATED ALWAYS AS ('link') STORED NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  token_hash BYTEA NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_by_id UUID NOT NULL,
  PRIMARY KEY (namespace_id, id),
  FOREIGN KEY (namespace_id, id, kind) REFERENCES grantees (namespace_id, id, kind) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (created_by_id) REFERENCES users (id)
);
CREATE INDEX ON share_links (organization_namespace_id, organization_id);
CREATE INDEX ON share_links (created_by_id);
ALTER TABLE share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE share_links FORCE ROW LEVEL SECURITY;

CREATE TABLE user_blocks (
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (organization_namespace_id, organization_id, user_id),
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id)
);
CREATE INDEX ON user_blocks (user_id);
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks FORCE ROW LEVEL SECURITY;

