setup
{
  INSERT INTO users (id) VALUES ('00000000-0000-0000-0000-000000000002');
  SET app.user_id = '00000000-0000-0000-0000-000000000002';
  BEGIN;
  INSERT INTO organizations (id, created_by_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000001', 'organization', '00000000-0000-0000-0000-000000000001');
  INSERT INTO memberships (organization_id, user_id, state) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'active');
  INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'user', 'admin');
  COMMIT;
  BEGIN;
  INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'folder', '00000000-0000-0000-0000-000000000001', 'organization');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000003', 'folder', '00000000-0000-0000-0000-000000000001');
  INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'project', '00000000-0000-0000-0000-000000000003', 'folder');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000004', 'project', '00000000-0000-0000-0000-000000000001');
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
  INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'folder', '00000000-0000-0000-0000-000000000003', 'folder');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000006', 'folder', '00000000-0000-0000-0000-000000000001');
}
step writer_finish { COMMIT; }

session observer
step stale_copies {
  SELECT
    (SELECT count(*) FROM resource_parents edge JOIN resources child ON child.id = edge.id JOIN resources parent ON parent.id = edge.parent_id
      WHERE edge.archived IS DISTINCT FROM child.archived OR edge.parent_archived IS DISTINCT FROM parent.archived
        OR child.inherits_archive IS DISTINCT FROM edge.parent_archived) AS stale_edges,
    (SELECT count(*) FROM ownables ownable JOIN resources own ON own.id = ownable.id JOIN resources project ON project.id = ownable.project_id
      WHERE ownable.archived IS DISTINCT FROM own.archived OR ownable.project_archived IS DISTINCT FROM project.archived
        OR own.inherits_archive IS DISTINCT FROM ownable.project_archived) AS stale_ownables,
    (SELECT count(*) FROM resources WHERE archived) AS archived_resources;
}

permutation archiver_begin archiver_archive writer_begin writer_folder archiver_finish writer_finish stale_copies
