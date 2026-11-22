\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(9);

SET ROLE identity_writer;
INSERT INTO users (id) VALUES ('10000000-0000-7000-8000-000000000001'), ('10000000-0000-7000-8000-000000000002');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000001');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000002');
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
  VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
INSERT INTO resources (id, kind, organization_id) VALUES
  ('40000000-0000-7000-8000-000000000003', 'folder', '20000000-0000-7000-8000-000000000002');
SELECT pg_temp.found_organization('20000000-0000-7000-8000-000000000003');
INSERT INTO share_links (id, organization_id, token_hash, created_by_id) VALUES
  ('a0000000-0000-7000-8000-000000000003', '20000000-0000-7000-8000-000000000003', decode(repeat('03', 32), 'hex'), '10000000-0000-7000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT results_eq($query$SELECT archived_at FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'
UNION ALL
SELECT (new_row ->> 'archived_at')::timestamptz FROM audit_events WHERE table_name = 'resources' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000003' AND (new_row ->> 'archived_at')::timestamptz = now()$query$, $expected$VALUES (now()), (now())$expected$, 'database stamps archived_at update');

RESET ROLE;
INSERT INTO resource_parents (organization_id, id, resource_kind, parent_id, parent_kind)
      VALUES ('20000000-0000-7000-8000-000000000002', '40000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000002', 'organization');
    INSERT INTO resources (id, kind, organization_id, archived_at) VALUES ('40000000-0000-7000-8000-000000000009', 'folder', '20000000-0000-7000-8000-000000000002', '2000-01-01');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT archived_at FROM resources WHERE id = '40000000-0000-7000-8000-000000000009'
UNION ALL
SELECT (new_row ->> 'archived_at')::timestamptz FROM audit_events WHERE table_name = 'resources' AND new_row ->> 'id' = '40000000-0000-7000-8000-000000000009' AND (new_row ->> 'archived_at')::timestamptz = now()$query$, $expected$VALUES (now()), (now())$expected$, 'database stamps archived_at insert');

SET ROLE app;
UPDATE resources SET archived_at = now() WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT archived_at AS original_archive_time FROM resources WHERE id = '40000000-0000-7000-8000-000000000003' \gset
RESET ROLE;
UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT is((SELECT archived_at FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'), :'original_archive_time'::timestamptz, 'stored archive timestamp is immutable');

SET ROLE app;
UPDATE resources SET archived_at = '2000-01-01' WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT is((SELECT archived_at FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'), :'original_archive_time'::timestamptz, 'application preserves the stored archive timestamp');

UPDATE resources SET archived_at = NULL WHERE id = '40000000-0000-7000-8000-000000000003';
SELECT is((SELECT archived_at FROM resources WHERE id = '40000000-0000-7000-8000-000000000003'), NULL::timestamptz, 'archive restoration keeps null');

UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003';
SELECT results_eq($query$SELECT revoked_at FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003'
UNION ALL
SELECT (new_row ->> 'revoked_at')::timestamptz FROM audit_events WHERE table_name = 'share_links' AND new_row ->> 'id' = 'a0000000-0000-7000-8000-000000000003' AND (new_row ->> 'revoked_at')::timestamptz = now()$query$, $expected$VALUES (now()), (now())$expected$, 'database stamps revoked_at update');

INSERT INTO share_links (id, organization_id, token_hash, created_by_id, revoked_at) VALUES ('a0000000-0000-7000-8000-000000000009', '20000000-0000-7000-8000-000000000003', decode(repeat('09', 32), 'hex'), '10000000-0000-7000-8000-000000000001', '2000-01-01');
SELECT results_eq($query$SELECT revoked_at FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000009'
UNION ALL
SELECT (new_row ->> 'revoked_at')::timestamptz FROM audit_events WHERE table_name = 'share_links' AND new_row ->> 'id' = 'a0000000-0000-7000-8000-000000000009' AND (new_row ->> 'revoked_at')::timestamptz = now()$query$, $expected$VALUES (now()), (now())$expected$, 'database stamps revoked_at insert');

UPDATE share_links SET revoked_at = now() WHERE id = 'a0000000-0000-7000-8000-000000000003';
SELECT revoked_at AS original_revocation_time FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003' \gset
RESET ROLE;
UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003';
SELECT is((SELECT revoked_at FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003'), :'original_revocation_time'::timestamptz, 'stored revocation timestamp is immutable');

SET ROLE app;
UPDATE share_links SET revoked_at = '2000-01-01' WHERE id = 'a0000000-0000-7000-8000-000000000003';
SELECT is((SELECT revoked_at FROM share_links WHERE id = 'a0000000-0000-7000-8000-000000000003'), :'original_revocation_time'::timestamptz, 'application preserves the stored revocation timestamp');


SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
