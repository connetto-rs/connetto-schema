# connetto-schema

[![Schema lint](https://github.com/connetto-rs/connetto-schema/actions/workflows/lint.yml/badge.svg)](https://github.com/connetto-rs/connetto-schema/actions/workflows/lint.yml)
[![Schema tests](https://github.com/connetto-rs/connetto-schema/actions/workflows/tests.yml/badge.svg)](https://github.com/connetto-rs/connetto-schema/actions/workflows/tests.yml)
[![Generated crates](https://github.com/connetto-rs/connetto-schema/actions/workflows/crates.yml/badge.svg)](https://github.com/connetto-rs/connetto-schema/actions/workflows/crates.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A PostgreSQL core schema for multi-tenant applications whose access rules live in row-level security. Its policies are written to translate one to one into an OpenFGA model through [rls2fga](https://github.com/connetto-rs/rls2fga), and [pg2sqlite](https://github.com/connetto-rs/pg2sqlite) turns the schema into the SQLite replica a client holds offline. Application schemas are applied on top of it.

```mermaid
erDiagram
    grantees ||--o| users : "is"
    grantees ||--o| organizations : "is"
    grantees ||--o| teams : "is"
    grantees ||--o| share_links : "is"
    grantees ||--o| app_installations : "is"
    users ||--o| platform_operators : "is"

    users ||--o{ organizations : "founds"
    organizations ||--o{ invitations : "sends"
    organizations ||--o{ memberships : "has"
    users ||--o{ memberships : "holds"
    invitations |o--o| memberships : "accepted as"
    organizations ||--o{ teams : "has"
    teams ||--o{ team_parents : "nests under"
    teams ||--o{ team_members : "has"
    memberships ||--o{ team_members : "joins"

    organizations ||--o{ resources : "owns"
    resources ||--o{ resource_parents : "nests under"
    resources ||--o| ownables : "is"
    resources ||--o{ grants : "shared by"
    grantees ||--o{ grants : "receives"
    organizations ||--o{ share_links : "issues"
    organizations ||--o{ organization_blocks : "blocks"
    grantees ||--o{ organization_blocks : "blocked"

    organizations ||--o{ apps : "publishes"
    apps ||--o{ app_installations : "installed as"
    organizations ||--o{ app_installations : "installs"
    app_installations ||--o{ installation_permissions : "allowed"

    grantees {
        uuid id PK
        grantee_kind kind "user, installation, team, organization, everyone, signed_in, link"
    }
    resources {
        uuid id PK
        resource_kind kind "organization, folder, project, ownable"
        uuid organization_id FK
        timestamptz archived_at
    }
    grants {
        uuid resource_id PK, FK
        uuid grantee_id PK, FK
        role role "reader, writer, admin"
        timestamptz expires_at
    }
    memberships {
        uuid organization_id PK, FK
        uuid user_id PK, FK
        membership_state state "active, deactivated"
    }
    audit_events {
        bigint id PK
        uuid organization_id
        text table_name
        audit_operation operation
    }
    platform_audit_events {
        bigint id PK
        text table_name
        audit_operation operation
    }
```

Anything that can receive access is a grantee, and a grant gives one grantee a role on one resource. Resources form a tree under their organization (folders, projects, and the ownables inside a project), and a grant on a node reaches everything below it. Triggers record every change to an organization's tables in `audit_events`, and every change to users, organizations and platform operators in `platform_audit_events`.

## Layout

| Path | Holds |
|---|---|
| [`sql/`](sql) | The schema, one slice per directory, applied in name order after [`cluster/roles.sql`](cluster/roles.sql) |
| [`crates/`](crates) | The [synql](https://github.com/connetto-rs/synql) crate `connetto-schema`, written by [`generate/`](generate). Its default `models` feature holds the Diesel models of every table and enum, `sqlite` adds their SQLite conversions, and with `default-features = false` it holds only the `DESCRIPTION` a schema generated on top of it reads |
| [`lint/`](lint) | The SQLippy and rls2fga configuration this schema is written for, which a schema built on top of it extends |
| [`tests/`](tests) | pgTAP behaviour tests, isolation specs, and scenarios run on PostgreSQL and on the SQLite replica side by side |
