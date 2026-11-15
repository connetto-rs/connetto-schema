-- Roles, the authz schema, and the grantee root every principal and audience shares.

CREATE ROLE app NOLOGIN;
CREATE ROLE identity_writer NOLOGIN;
CREATE ROLE authz_owner NOLOGIN BYPASSRLS;
CREATE ROLE authz_writer NOLOGIN BYPASSRLS;

CREATE SCHEMA authz;
REVOKE ALL ON SCHEMA authz FROM PUBLIC;
GRANT USAGE ON SCHEMA authz TO app, authz_owner;

-- Everything a grant can name. Each kind is a table sharing the id through (id, kind).
CREATE TABLE grantees (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('user', 'installation', 'team', 'organization', 'everyone', 'signed_in', 'link')),
  UNIQUE (id, kind)
);
ALTER TABLE grantees ENABLE ROW LEVEL SECURITY;
ALTER TABLE grantees FORCE ROW LEVEL SECURITY;

-- The two audiences, under fixed ids no client-minted UUIDv7 can take.
INSERT INTO grantees (id, kind) VALUES
  ('00000000-0000-0000-0000-000000000001', 'everyone'),
  ('00000000-0000-0000-0000-000000000002', 'signed_in');

CREATE TABLE users (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'user' CHECK (kind = 'user'),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

CREATE TABLE platform_operators (
  id UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE
);
ALTER TABLE platform_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_operators FORCE ROW LEVEL SECURITY;
