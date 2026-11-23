CREATE TABLE resources (
  id UUID PRIMARY KEY,
  kind authz.resource_kind NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  archived_at TIMESTAMPTZ,
  -- An ancestor is archived. Each table's archive policies read archived on their own row,
  -- through copies that the foreign keys onto archived keep equal.
  inherits_archive BOOLEAN NOT NULL DEFAULT FALSE,
  archived BOOLEAN GENERATED ALWAYS AS (archived_at IS NOT NULL OR inherits_archive) STORED NOT NULL,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (organization_id, id, archived),
  UNIQUE (organization_id, id, kind, archived),
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
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  parent_archived BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (organization_id, id, resource_kind),
  FOREIGN KEY (organization_id, id, resource_kind, archived) REFERENCES resources (organization_id, id, kind, archived)
    ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_id, parent_id, parent_kind, parent_archived) REFERENCES resources (organization_id, id, kind, archived)
    ON UPDATE CASCADE
);
CREATE INDEX ON resource_parents (parent_id);
ALTER TABLE resource_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_parents FORCE ROW LEVEL SECURITY;

CREATE TABLE ownables (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  kind authz.resource_kind NOT NULL DEFAULT 'ownable' CHECK (kind = 'ownable'),
  project_id UUID NOT NULL,
  project_kind authz.resource_kind NOT NULL DEFAULT 'project' CHECK (project_kind = 'project'),
  created_by_id UUID NOT NULL REFERENCES users (id),
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  project_archived BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (id, project_id),
  UNIQUE (organization_id, id, kind),
  FOREIGN KEY (organization_id, id, kind, archived) REFERENCES resources (organization_id, id, kind, archived)
    ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY (organization_id, project_id, project_kind, project_archived) REFERENCES resources (organization_id, id, kind, archived)
    ON UPDATE CASCADE
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
