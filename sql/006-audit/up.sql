-- The append-only record of every change to grants, memberships, invitations, blocks and installations.

-- No foreign keys, so the record outlives the rows, principals and organizations it names.
CREATE TABLE audit_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  at TIMESTAMPTZ NOT NULL,
  organization_id UUID NOT NULL,
  actor_id UUID,
  original_actor_id UUID,
  installation_id UUID,
  table_name TEXT NOT NULL CHECK (table_name <> '' AND length(table_name) <= 63),
  operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  old JSONB,
  new JSONB,
  CHECK (old IS NOT NULL OR new IS NOT NULL)
);
CREATE INDEX ON audit_events (organization_id, at);
ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events FORCE ROW LEVEL SECURITY;
