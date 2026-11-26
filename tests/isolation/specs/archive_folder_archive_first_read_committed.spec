setup
{
  INSERT INTO users (id) VALUES ('00000000-0000-0000-0000-000000000002');
  SET app.user_id = '00000000-0000-0000-0000-000000000002';
  BEGIN;
  INSERT INTO organizations (id, created_by_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000001', 'organization', '00000000-0000-0000-0000-000000000001');
  INSERT INTO memberships (organization_id, user_id, state) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'active');
  COMMIT;
  BEGIN;
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'folder', '00000000-0000-0000-0000-000000000001', 'organization');
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'project', '00000000-0000-0000-0000-000000000003', 'folder');
  COMMIT;
}

session archiver
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step archiver_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step archiver_archive { UPDATE resources SET archived_at = now() WHERE id = '00000000-0000-0000-0000-000000000003'; }
step archiver_finish { COMMIT; }

session writer
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step writer_begin { BEGIN ISOLATION LEVEL READ COMMITTED; }
step writer_folder {
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'folder', '00000000-0000-0000-0000-000000000003', 'folder');
}
step writer_finish { COMMIT; }

session observer
step stale_copies {
  SELECT
    (SELECT count(*) FROM resources child JOIN resources parent ON parent.id = child.parent_id
      WHERE child.kind IN ('folder', 'project') AND (child.parent_archived IS DISTINCT FROM parent.archived
        OR child.inherits_archive IS DISTINCT FROM child.parent_archived)) AS stale_edges,
    (SELECT count(*) FROM resources ownable JOIN resources project ON project.id = ownable.parent_id
      WHERE ownable.kind = 'ownable' AND (ownable.parent_archived IS DISTINCT FROM project.archived
        OR ownable.inherits_archive IS DISTINCT FROM ownable.parent_archived)) AS stale_ownables,
    (SELECT count(*) FROM resources WHERE archived) AS archived_resources;
}

permutation archiver_begin archiver_archive writer_begin writer_folder archiver_finish writer_finish stale_copies
