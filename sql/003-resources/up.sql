CREATE TABLE resources (
  id UUID PRIMARY KEY,
  kind authz.resource_kind NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  archived_at TIMESTAMPTZ,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, id, kind),
  CHECK ((kind = 'organization') = (id = organization_id))
);
CREATE INDEX ON resources (id) WHERE archived_at IS NOT NULL;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources FORCE ROW LEVEL SECURITY;

CREATE TABLE resource_parents (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  resource_kind authz.resource_kind NOT NULL CHECK (resource_kind IN ('folder', 'project')),
  parent_id UUID NOT NULL CHECK (parent_id <> id),
  parent_kind authz.resource_kind NOT NULL CHECK (parent_kind IN ('organization', 'folder')),
  UNIQUE (organization_id, id, resource_kind),
  FOREIGN KEY (organization_id, id, resource_kind) REFERENCES resources (organization_id, id, kind) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_id, parent_id, parent_kind) REFERENCES resources (organization_id, id, kind)
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
  UNIQUE (organization_id, id, kind),
  FOREIGN KEY (organization_id, id, kind) REFERENCES resources (organization_id, id, kind) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_id, project_id, project_kind) REFERENCES resources (organization_id, id, kind)
);
CREATE INDEX ON ownables (project_id);
CREATE INDEX ON ownables (created_by_id);
ALTER TABLE ownables ENABLE ROW LEVEL SECURITY;
ALTER TABLE ownables FORCE ROW LEVEL SECURITY;

ALTER TABLE resources
  ADD COLUMN ownable_id UUID GENERATED ALWAYS AS (CASE WHEN kind = 'ownable' THEN id END) STORED,
  ADD COLUMN edge_id UUID GENERATED ALWAYS AS (CASE WHEN kind IN ('folder', 'project') THEN id END) STORED,
  ADD FOREIGN KEY (organization_id, ownable_id, kind) REFERENCES ownables (organization_id, id, kind) ON DELETE RESTRICT NOT DEFERRABLE,
  ADD FOREIGN KEY (organization_id, edge_id, kind) REFERENCES resource_parents (organization_id, id, resource_kind) ON DELETE RESTRICT NOT DEFERRABLE;
CREATE INDEX ON resources (ownable_id);
CREATE INDEX ON resources (edge_id);
