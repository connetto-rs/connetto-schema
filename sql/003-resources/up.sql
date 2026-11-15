-- Optional nested folders, projects, and the ownables every protected row hangs from.

CREATE TABLE folders (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (organization_id, id)
);
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders FORCE ROW LEVEL SECURITY;

-- A root folder has no row here.
CREATE TABLE folder_parents (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  folder_id UUID NOT NULL REFERENCES folders (id),
  parent_id UUID NOT NULL REFERENCES folders (id) CHECK (parent_id <> folder_id),
  PRIMARY KEY (organization_id, folder_id),
  FOREIGN KEY (organization_id, folder_id) REFERENCES folders (organization_id, id),
  FOREIGN KEY (organization_id, parent_id) REFERENCES folders (organization_id, id)
);
CREATE UNIQUE INDEX ON folder_parents (folder_id);
CREATE INDEX ON folder_parents (organization_id, parent_id);
CREATE INDEX ON folder_parents (parent_id);
ALTER TABLE folder_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE folder_parents FORCE ROW LEVEL SECURITY;

CREATE TABLE projects (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (organization_id, id)
);
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects FORCE ROW LEVEL SECURITY;

-- A project directly under its organization has no row here.
CREATE TABLE project_folders (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  project_id UUID NOT NULL REFERENCES projects (id),
  folder_id UUID NOT NULL REFERENCES folders (id),
  PRIMARY KEY (organization_id, project_id),
  FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id),
  FOREIGN KEY (organization_id, folder_id) REFERENCES folders (organization_id, id)
);
CREATE UNIQUE INDEX ON project_folders (project_id);
CREATE INDEX ON project_folders (organization_id, folder_id);
CREATE INDEX ON project_folders (folder_id);
ALTER TABLE project_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_folders FORCE ROW LEVEL SECURITY;

-- Protected child tables reference (id, project_id) ON UPDATE CASCADE, so a move carries their rows.
CREATE TABLE ownables (
  id UUID PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES projects (id),
  created_by_id UUID NOT NULL REFERENCES users (id),
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  writers_can_share BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (id, project_id)
);
CREATE INDEX ON ownables (project_id);
CREATE INDEX ON ownables (created_by_id);
ALTER TABLE ownables ENABLE ROW LEVEL SECURITY;
ALTER TABLE ownables FORCE ROW LEVEL SECURITY;
