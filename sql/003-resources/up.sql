CREATE TABLE resources (
  id UUID PRIMARY KEY,
  kind authz.resource_kind NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  archived_at TIMESTAMPTZ,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (id, kind),
  UNIQUE (organization_id, id),
  CHECK ((kind = 'organization') = (id = organization_id))
);
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources FORCE ROW LEVEL SECURITY;

CREATE TABLE resource_parents (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  resource_kind authz.resource_kind NOT NULL CHECK (resource_kind IN ('folder', 'project')),
  parent_id UUID NOT NULL CHECK (parent_id <> id),
  parent_kind authz.resource_kind NOT NULL CHECK (parent_kind IN ('organization', 'folder')),
  FOREIGN KEY (organization_id, id) REFERENCES resources (organization_id, id) ON DELETE CASCADE,
  FOREIGN KEY (organization_id, parent_id) REFERENCES resources (organization_id, id),
  FOREIGN KEY (id, resource_kind) REFERENCES resources (id, kind) ON DELETE CASCADE,
  FOREIGN KEY (parent_id, parent_kind) REFERENCES resources (id, kind)
);
CREATE INDEX ON resource_parents (parent_id);
ALTER TABLE resource_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_parents FORCE ROW LEVEL SECURITY;

CREATE TABLE ownables (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  kind authz.resource_kind GENERATED ALWAYS AS ('ownable'::authz.resource_kind) STORED NOT NULL,
  project_id UUID NOT NULL,
  project_kind authz.resource_kind GENERATED ALWAYS AS ('project'::authz.resource_kind) STORED NOT NULL,
  created_by_id UUID NOT NULL REFERENCES users (id),
  UNIQUE (id, project_id),
  FOREIGN KEY (id, kind) REFERENCES resources (id, kind) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_id, id) REFERENCES resources (organization_id, id) DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (project_id, project_kind) REFERENCES resources (id, kind),
  FOREIGN KEY (organization_id, project_id) REFERENCES resources (organization_id, id)
);
CREATE INDEX ON ownables (project_id);
CREATE INDEX ON ownables (created_by_id);
ALTER TABLE ownables ENABLE ROW LEVEL SECURITY;
ALTER TABLE ownables FORCE ROW LEVEL SECURITY;
