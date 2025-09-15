DC=docker compose -f docker-compose.yml
DB_USER?=user
DB_NAME?=mydb

# seed params (can override: make seed owners=2000 ppo=3 minr=2 maxr=20 ap=0.7)
owners?=1000
ppo?=2
minr?=1
maxr?=50
ap?=0.6

.PHONY: up down logs psql schema seed seed-consistent index-before index-create index-after backup restore status help

help:
	@echo "Targets:"
	@echo "  up, down, logs, status, psql"
	@echo "  schema            # create Prisma-like tables"
	@echo "  seed              # consistent seed (owners=$(owners), ppo=$(ppo), records=$(minr)..$(maxr), ap=$(ap))"
	@echo "  index-before|index-create|index-after  # db_probes explain/index demo"
	@echo "  backup|restore"

up:
	$(DC) up -d

down:
	$(DC) down

logs:
	$(DC) logs -f db

status:
	$(DC) ps

psql:
	$(DC) exec -it db psql -U $(DB_USER) -d $(DB_NAME)

schema:
	# stream schema file into container psql
	$(DC) exec -T db psql -U $(DB_USER) -d $(DB_NAME) -f - < sql/schema_prisma.sql

seed seed-consistent:
	# use repo's seed script; adjust params via make vars
	$(DC) exec -T db psql -U $(DB_USER) -d $(DB_NAME) \
		-v owners_count=$(owners) -v patients_per_owner=$(ppo) \
		-v min_records=$(minr) -v max_records=$(maxr) -v appointment_prob=$(ap) \
		-f - < ../sql/seed/seed_prisma_consistent.sql

index-before:
	$(DC) exec -T db psql -U $(DB_USER) -d $(DB_NAME) -f - < ../sql/indexing/explain_scan_before.sql

index-create:
	$(DC) exec -T db psql -U $(DB_USER) -d $(DB_NAME) -f - < ../sql/indexing/create_idx_db_probes_created_at.sql

index-after:
	$(DC) exec -T db psql -U $(DB_USER) -d $(DB_NAME) -f - < ../sql/indexing/explain_scan_after.sql

backup:
	# run from repo root: DATABASE_URL=postgres://user:password@localhost:5435/mydb ./scripts/db-backup.sh
	@echo "Run: DATABASE_URL=postgres://user:password@localhost:5435/mydb ./scripts/db-backup.sh"

restore:
	# run from repo root: DATABASE_URL=... ./scripts/db-restore.sh backups/<file>.dump --force
	@echo "Run: DATABASE_URL=postgres://user:password@localhost:5435/mydb ./scripts/db-restore.sh backups/<file>.dump --force"

