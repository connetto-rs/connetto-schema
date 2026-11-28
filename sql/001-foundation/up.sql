CREATE SCHEMA authz;
REVOKE ALL ON SCHEMA authz FROM PUBLIC;
GRANT USAGE ON SCHEMA authz TO app, authz_owner, identity_writer;

CREATE TYPE authz.role AS ENUM ('reader', 'writer', 'admin');
CREATE TYPE authz.resource_kind AS ENUM ('organization', 'folder', 'project', 'ownable');
CREATE TYPE authz.grantee_kind AS ENUM ('user', 'installation', 'team', 'organization', 'everyone', 'signed_in', 'link');
CREATE TYPE authz.membership_state AS ENUM ('active', 'deactivated');
CREATE TYPE authz.team_role AS ENUM ('member', 'admin');
CREATE TYPE authz.audit_operation AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- Holds no reference to its owner, which names it through `owned_namespace_id`, so a namespace outlives its owner.
CREATE TABLE namespaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reserved BOOLEAN NOT NULL DEFAULT false,
  CHECK (reserved = (id = 'bc3cf2e2-768c-4af9-bf86-65f23378a212'))
);
CREATE UNIQUE INDEX ON namespaces (reserved) WHERE reserved;
ALTER TABLE namespaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE namespaces FORCE ROW LEVEL SECURITY;
INSERT INTO namespaces (id, reserved) VALUES ('bc3cf2e2-768c-4af9-bf86-65f23378a212', true);

-- The two audiences hold the reserved namespace, which no client creates in.
CREATE TABLE grantees (
  namespace_id UUID NOT NULL REFERENCES namespaces (id),
  id UUID NOT NULL,
  kind authz.grantee_kind NOT NULL CHECK (kind <> 'user'),
  PRIMARY KEY (namespace_id, id),
  UNIQUE (namespace_id, id, kind),
  CHECK ((kind IN ('everyone', 'signed_in')) = (namespace_id = 'bc3cf2e2-768c-4af9-bf86-65f23378a212'))
);
ALTER TABLE grantees ENABLE ROW LEVEL SECURITY;
ALTER TABLE grantees FORCE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX ON grantees (kind) WHERE kind IN ('everyone', 'signed_in');
INSERT INTO grantees (namespace_id, id, kind) VALUES
  ('bc3cf2e2-768c-4af9-bf86-65f23378a212', gen_random_uuid(), 'everyone'),
  ('bc3cf2e2-768c-4af9-bf86-65f23378a212', gen_random_uuid(), 'signed_in');

-- `owned_namespace_id` is the namespace the user creates in, never the namespace of its own identity.
CREATE TABLE users (
  id UUID NOT NULL,
  owned_namespace_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  PRIMARY KEY (id),
  FOREIGN KEY (owned_namespace_id) REFERENCES namespaces (id) DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

CREATE TABLE platform_operators (
  id UUID NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (id) REFERENCES users (id) ON DELETE CASCADE
);
ALTER TABLE platform_operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_operators FORCE ROW LEVEL SECURITY;
