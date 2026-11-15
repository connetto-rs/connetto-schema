-- Applications, their installations into organizations, and the permissions each installer approved.

-- An app belongs to the organization whose admins registered it.
CREATE TABLE apps (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  name TEXT NOT NULL CHECK (name <> '' AND length(name) <= 200)
);
CREATE INDEX ON apps (organization_id);
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE apps FORCE ROW LEVEL SECURITY;

-- An installation acts as itself and receives grants like a person.
CREATE TABLE app_installations (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL DEFAULT 'installation' CHECK (kind = 'installation'),
  app_id UUID NOT NULL REFERENCES apps (id),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind)
);
CREATE INDEX ON app_installations (app_id);
CREATE INDEX ON app_installations (organization_id);
ALTER TABLE app_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_installations FORCE ROW LEVEL SECURITY;

-- On behalf of a user, an installation reaches only these tables and commands, on every grant path.
CREATE TABLE installation_permissions (
  installation_id UUID NOT NULL REFERENCES app_installations (id),
  table_name TEXT NOT NULL CHECK (table_name <> '' AND length(table_name) <= 63),
  action TEXT NOT NULL CHECK (action IN ('select', 'insert', 'update', 'delete')),
  PRIMARY KEY (installation_id, table_name, action)
);
ALTER TABLE installation_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE installation_permissions FORCE ROW LEVEL SECURITY;
