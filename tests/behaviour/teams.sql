\set ON_ERROR_STOP 1
SET search_path = public, test_tools;
BEGIN;
\ir ../fixture.sql
SELECT plan(15);

SELECT pg_temp.provision('10000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT pg_temp.found_organization(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000002', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001');
SELECT pg_temp.add_member(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT throws_ok($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000002' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000002'$statement$, '23514', 'team 30000000-0000-7000-8000-000000000002 would become its own ancestor', 'team cannot parent itself');

SELECT throws_ok($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000002' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000001'$statement$, '23514', 'team 30000000-0000-7000-8000-000000000001 would become its own ancestor', 'team cycle is rejected');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT throws_ok($statement$SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-000000000003', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000001')$statement$, '42501', NULL, 'member cannot create child team');

RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001');
INSERT INTO team_members (team_namespace_id, team_id, organization_namespace_id, organization_id, user_id, team_role) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001', '10000000-0000-7000-8000-000000000002', 'admin');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('app.user_id', '10000000-0000-7000-8000-000000000002', true);
SELECT throws_ok($statement$SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-00000000000d', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009')$statement$, '42501', NULL, 'team admin cannot create a child team in the founder''s namespace');
SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-00000000000a', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SELECT results_eq($query$SELECT parent_namespace_id, parent_id FROM teams WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-00000000000a'$query$, $expected$VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-000000000009'::uuid)$expected$, 'team admin creates a child team in its own namespace under a parent in another');

SELECT throws_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), '30000000-0000-7000-8000-00000000000b', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'); SET CONSTRAINTS ALL IMMEDIATE$statement$, '42501', NULL, 'team admin cannot create a root team');

RESET ROLE;
SELECT lives_ok($statement$INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id) VALUES (pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '30000000-0000-7000-8000-00000000000c', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), '20000000-0000-7000-8000-000000000001'); DELETE FROM teams WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-00000000000c'; SET CONSTRAINTS ALL IMMEDIATE$statement$, 'team root can be inserted and deleted in one transaction');

SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000002');
SET ROLE app;
SELECT is_empty($query$UPDATE teams SET parent_namespace_id = NULL, parent_id = NULL WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-00000000000a' RETURNING id$query$, 'team admin cannot detach a child');
SELECT is_empty($query$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000001' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-00000000000a' RETURNING id$query$, 'team admin cannot move a child');
RESET ROLE;
SELECT pg_temp.act('10000000-0000-7000-8000-000000000001');
SET ROLE app;
SELECT results_eq($query$UPDATE teams SET parent_namespace_id = NULL, parent_id = NULL WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-00000000000a' RETURNING parent_id$query$, $expected$VALUES (NULL::uuid)$expected$, 'organization admin detaches a child');
SELECT results_eq($query$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000009' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002') AND id = '30000000-0000-7000-8000-00000000000a' RETURNING parent_id$query$, $expected$VALUES ('30000000-0000-7000-8000-000000000009'::uuid)$expected$, 'organization admin attaches a root');
SELECT throws_ok($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000002'), parent_id = '30000000-0000-7000-8000-000000000009' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = '30000000-0000-7000-8000-000000000002'$statement$, '23503', NULL, 'a parent pair naming the parent''s local id in another namespace is refused');
SET CONSTRAINTS ALL DEFERRED;
DO $body$
DECLARE
  level INTEGER;
  parent UUID;
  child UUID;
  creation UUID := pg_temp.namespace_of('10000000-0000-7000-8000-000000000001');
BEGIN
  FOR level IN 1..20 LOOP
    child := ('b0000000-0000-7000-8000-' || lpad(level::text, 12, '0'))::uuid;
    INSERT INTO teams (namespace_id, id, organization_namespace_id, organization_id, parent_namespace_id, parent_id)
      VALUES (creation, child, creation, '20000000-0000-7000-8000-000000000001', CASE WHEN parent IS NOT NULL THEN creation END, parent);
    parent := child;
  END LOOP;
END
$body$;
SELECT throws_ok($statement$SELECT pg_temp.create_child_team(pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'b0000000-0000-7000-8000-000000000021', pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), 'b0000000-0000-7000-8000-000000000020')$statement$, '23514', NULL, 'team depth includes its root');
SELECT throws_ok($statement$UPDATE teams SET parent_namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001'), parent_id = '30000000-0000-7000-8000-000000000001' WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = 'b0000000-0000-7000-8000-000000000001'$statement$, '23514', NULL, 'moving a team checks descendant depth');
SELECT results_eq($query$UPDATE teams SET parent_namespace_id = NULL, parent_id = NULL WHERE namespace_id = pg_temp.namespace_of('10000000-0000-7000-8000-000000000001') AND id = 'b0000000-0000-7000-8000-000000000002' RETURNING parent_id$query$, $expected$VALUES (NULL::uuid)$expected$, 'detaching a team preserves its descendants');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
