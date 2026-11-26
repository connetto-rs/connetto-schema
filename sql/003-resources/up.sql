CREATE TABLE resources (
  id UUID PRIMARY KEY,
  kind authz.resource_kind NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  parent_id UUID CHECK (parent_id <> id),
  parent_kind authz.resource_kind,
  created_by_id UUID REFERENCES users (id),
  archived_at TIMESTAMPTZ,
  parent_archived BOOLEAN NOT NULL DEFAULT FALSE,
  inherits_archive BOOLEAN NOT NULL DEFAULT FALSE,
  archived BOOLEAN GENERATED ALWAYS AS (archived_at IS NOT NULL OR inherits_archive) STORED NOT NULL,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (id, parent_id),
  UNIQUE (organization_id, id, archived),
  UNIQUE (organization_id, id, kind, archived),
  CHECK ((kind = 'organization') = (id = organization_id)),
  CHECK ((kind = 'organization') = (parent_id IS NULL)),
  CHECK ((kind = 'organization') = (parent_kind IS NULL)),
  CHECK (
    kind = 'organization'
    OR (kind IN ('folder', 'project') AND parent_kind IN ('organization', 'folder'))
    OR (kind = 'ownable' AND parent_kind = 'project')
  ),
  CHECK ((kind = 'ownable') = (created_by_id IS NOT NULL)),
  CHECK (inherits_archive = parent_archived),
  CHECK (kind <> 'organization' OR NOT parent_archived),
  CONSTRAINT resources_parent_archive_fkey FOREIGN KEY (organization_id, parent_id, parent_kind, parent_archived)
    REFERENCES resources (organization_id, id, kind, archived) ON UPDATE CASCADE
);
CREATE INDEX ON resources (parent_id);
CREATE INDEX ON resources (created_by_id);
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources FORCE ROW LEVEL SECURITY;

