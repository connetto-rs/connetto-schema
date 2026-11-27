CREATE SCHEMA authz;
REVOKE ALL ON SCHEMA authz FROM PUBLIC;
GRANT USAGE ON SCHEMA authz TO app, authz_owner;

CREATE TYPE authz.role AS ENUM ('reader', 'writer', 'admin');
CREATE TYPE authz.resource_kind AS ENUM ('organization', 'folder', 'project', 'ownable');
CREATE TYPE authz.grantee_kind AS ENUM ('user', 'installation', 'team', 'organization', 'everyone', 'signed_in', 'link');
CREATE TYPE authz.membership_state AS ENUM ('active', 'deactivated');
CREATE TYPE authz.team_role AS ENUM ('member', 'admin');
CREATE TYPE authz.audit_operation AS ENUM ('INSERT', 'UPDATE', 'DELETE');

CREATE TABLE grantees (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind NOT NULL,
  UNIQUE (id, kind)
);
ALTER TABLE grantees ENABLE ROW LEVEL SECURITY;
ALTER TABLE grantees FORCE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX ON grantees (kind) WHERE kind IN ('everyone', 'signed_in');
INSERT INTO grantees (id, kind) VALUES
  (gen_random_uuid(), 'everyone'), (gen_random_uuid(), 'signed_in');

CREATE TABLE users (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind NOT NULL DEFAULT 'user' CHECK (kind = 'user'),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind) ON DELETE CASCADE
);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

CREATE TABLE namespaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users (id) ON DELETE SET NULL,
  reserved BOOLEAN NOT NULL DEFAULT false,
  CHECK (NOT reserved OR user_id IS NULL)
);
CREATE UNIQUE INDEX ON namespaces (user_id);
CREATE UNIQUE INDEX ON namespaces (reserved) WHERE reserved;
ALTER TABLE namespaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE namespaces FORCE ROW LEVEL SECURITY;
INSERT INTO namespaces (id, reserved) VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212', true);

CREATE TABLE platform_operators (
  id UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE
);
ALTER TABLE platform_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_operators FORCE ROW LEVEL SECURITY;
