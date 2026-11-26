setup
{
  TRUNCATE users, organizations, audit_events, platform_audit_events CASCADE;
  INSERT INTO users (id) VALUES ('00000000-0000-0000-0000-000000000002');
  SET app.user_id = '00000000-0000-0000-0000-000000000002';
  BEGIN;
  INSERT INTO organizations (id, created_by_id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
  INSERT INTO resources (id, kind, organization_id) VALUES ('00000000-0000-0000-0000-000000000001', 'organization', '00000000-0000-0000-0000-000000000001');
  INSERT INTO memberships (organization_id, user_id, state) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'active');
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
    VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'folder', '00000000-0000-0000-0000-000000000001', 'organization');
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
    VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'project', '00000000-0000-0000-0000-000000000003', 'folder');
  COMMIT;
}

session remover
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step remover_begin { BEGIN; }
step remover_delete { DELETE FROM resources WHERE id = '00000000-0000-0000-0000-000000000003'; }
step remover_finish { COMMIT; }

session writer
setup { SET statement_timeout = '20s'; SET app.user_id = '00000000-0000-0000-0000-000000000002'; SET ROLE app; }
step writer_begin { BEGIN; }
step writer_insert {
  INSERT INTO resources (organization_id, id, kind, parent_id, parent_kind)
    VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'folder', '00000000-0000-0000-0000-000000000003', 'folder');
}
step writer_finish { COMMIT; }

session observer
step remaining {
  SELECT (SELECT count(*) FROM resources WHERE kind <> 'organization') AS resources,
    (SELECT count(*) FROM resources WHERE parent_id IS NOT NULL) AS children,
    (SELECT count(*) FROM resources WHERE kind = 'ownable') AS ownables;
}

permutation writer_begin writer_insert remover_begin remover_delete writer_finish remover_finish remaining
permutation remover_begin remover_delete writer_begin writer_insert remover_finish writer_finish remaining
