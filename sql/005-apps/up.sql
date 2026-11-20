CREATE TABLE apps (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  name TEXT NOT NULL CHECK (name <> '' AND length(name) <= 200)
);
CREATE INDEX ON apps (organization_id);
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE apps FORCE ROW LEVEL SECURITY;

CREATE TABLE app_installations (
  id UUID PRIMARY KEY,
  kind authz.grantee_kind GENERATED ALWAYS AS ('installation'::authz.grantee_kind) STORED NOT NULL,
  app_id UUID NOT NULL REFERENCES apps (id),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  UNIQUE (organization_id, id),
  FOREIGN KEY (id, kind) REFERENCES grantees (id, kind) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ON app_installations (app_id);
ALTER TABLE app_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_installations FORCE ROW LEVEL SECURITY;

CREATE TABLE installation_permissions (
  installation_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  kind authz.resource_kind NOT NULL,
  max_role authz.role NOT NULL,
  PRIMARY KEY (installation_id, kind),
  FOREIGN KEY (organization_id, installation_id) REFERENCES app_installations (organization_id, id)
);
CREATE INDEX ON installation_permissions (organization_id, installation_id);
ALTER TABLE installation_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE installation_permissions FORCE ROW LEVEL SECURITY;
