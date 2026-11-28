CREATE TABLE apps (
  id UUID PRIMARY KEY,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  name TEXT NOT NULL CHECK (name <> '' AND length(name) <= 200),
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id)
);
CREATE INDEX ON apps (organization_namespace_id, organization_id);
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE apps FORCE ROW LEVEL SECURITY;

-- `owned_namespace_id` is the namespace the installation creates in when it acts alone.
CREATE TABLE app_installations (
  namespace_id UUID NOT NULL,
  id UUID NOT NULL,
  kind authz.grantee_kind GENERATED ALWAYS AS ('installation') STORED NOT NULL,
  app_id UUID NOT NULL REFERENCES apps (id),
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  owned_namespace_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  PRIMARY KEY (namespace_id, id),
  UNIQUE (organization_namespace_id, organization_id, namespace_id, id),
  FOREIGN KEY (namespace_id, id, kind) REFERENCES grantees (namespace_id, id, kind) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (owned_namespace_id) REFERENCES namespaces (id) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ON app_installations (app_id);
ALTER TABLE app_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_installations FORCE ROW LEVEL SECURITY;

CREATE TABLE installation_permissions (
  installation_namespace_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  kind authz.resource_kind NOT NULL,
  max_role authz.role NOT NULL,
  PRIMARY KEY (organization_namespace_id, organization_id, installation_namespace_id, installation_id, kind),
  FOREIGN KEY (organization_namespace_id, organization_id, installation_namespace_id, installation_id)
    REFERENCES app_installations (organization_namespace_id, organization_id, namespace_id, id)
);
ALTER TABLE installation_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE installation_permissions FORCE ROW LEVEL SECURITY;

CREATE TABLE installation_blocks (
  organization_namespace_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  installation_namespace_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (organization_namespace_id, organization_id, installation_namespace_id, installation_id),
  FOREIGN KEY (organization_namespace_id, organization_id) REFERENCES organizations (namespace_id, id),
  FOREIGN KEY (installation_namespace_id, installation_id) REFERENCES app_installations (namespace_id, id) ON DELETE CASCADE
);
CREATE INDEX ON installation_blocks (installation_namespace_id, installation_id);
ALTER TABLE installation_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE installation_blocks FORCE ROW LEVEL SECURITY;
