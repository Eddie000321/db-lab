# DB Lab (Postgres-only)

Self-contained PostgreSQL lab for schema + seed + indexing experiments.

## Quick Start

```bash
cd db-lab
make up          # start Postgres on host port 5435
make schema      # create Prisma-like tables
make seed        # load consistent seed (owners=1000, ppo=2, records=1..50, ap=0.6)
make psql        # open psql shell
```

Customize seed sizes:

```bash
make seed owners=2000 ppo=3 minr=5 maxr=30 ap=0.7
```

## Useful Commands

- Start/Stop/Status
  - `make up`, `make down`, `make status`, `make logs`
- SQL shell
  - `make psql` (db user: `user`, db: `mydb`)
- Schema
  - `make schema` applies `sql/schema_prisma.sql`
- Seed data
  - `make seed` streams `../sql/seed/seed_prisma_consistent.sql` into the container
- Indexing demo
  - `make index-before` → run EXPLAIN before index
  - `make index-create` → create index on `db_probes(created_at desc)`
  - `make index-after` → run EXPLAIN after index
- Backup/Restore
  - See hints in `make backup` / `make restore` (run scripts from repo root)

## Notes

- This lab runs its own Postgres mapped to `localhost:5435` (to avoid conflict with root compose at 5434).
- Seed file targets quoted table names ("Owner", "Patient", etc.) that mirror the Prisma schema used by the app.
- You can safely use this lab without running the app; all SQL is standard PostgreSQL.

