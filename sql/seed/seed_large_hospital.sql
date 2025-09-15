-- Large hospital synthetic dataset seeder (owners + patients)
-- Usage:
--   psql $DATABASE_URL -v owners_count=400000 -v patients_count=1000000 -f sql/seed/seed_large_hospital.sql
-- Notes:
-- - Safe to re-run: truncates target tables. Adjust counts via -v vars.
-- - Generates realistic distributions and adds useful indexes for queries.

\set ON_ERROR_STOP on
\echo Seeding large hospital dataset...

-- Defaults if not provided by -v (psql 14+)
\if :{?owners_count}
\else
  \set owners_count 400000
\endif
\if :{?patients_count}
\else
  \set patients_count 1000000
\endif

-- Speed up bulk load for this session
SET client_min_messages = warning;
SET lock_timeout = '0';
SET statement_timeout = '0';
SET maintenance_work_mem = '512MB';
SET synchronous_commit = off;

-- Schema (minimal, independent of Prisma runtime)
CREATE TABLE IF NOT EXISTS owners (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name  TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  phone      TEXT,
  address    TEXT,
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patients (
  id BIGSERIAL PRIMARY KEY,
  owner_id BIGINT NOT NULL REFERENCES owners(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  species TEXT NOT NULL,
  breed TEXT,
  age INT,
  gender TEXT,
  weight NUMERIC(6,2),
  weight_unit TEXT NOT NULL DEFAULT 'lbs',
  status TEXT NOT NULL DEFAULT 'active',
  assigned_doctor TEXT,
  handling_difficulty TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Start fresh for deterministic IDs/ratios (handle FK with CASCADE atomically)
TRUNCATE TABLE patients, owners RESTART IDENTITY CASCADE;

-- Reference arrays for sampling
WITH params AS (
  SELECT
    ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','William','Elizabeth','David','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Charles','Karen'] AS first_names,
    ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'] AS last_names
)
INSERT INTO owners (first_name, last_name, email, phone, address, notes, created_at)
SELECT
  fn AS first_name,
  ln AS last_name,
  'owner'||g::text||'@example.com' AS email,
  '('||lpad(((random()*900)::int + 100)::text,3,'0')||') '||lpad(((random()*900)::int + 100)::text,3,'0')||'-'||lpad(((random()*9000)::int + 1000)::text,4,'0') AS phone,
  ((g % 9999) + 1)::text || ' Main St, Springfield, ST ' || lpad(((g % 99999) + 1)::text,5,'0') AS address,
  CASE WHEN random() < 0.2 THEN 'Prefers morning appointments' ELSE NULL END AS notes,
  now() - (random()*interval '365 days') AS created_at
FROM generate_series(1, :owners_count) AS gs(g)
CROSS JOIN LATERAL (
  SELECT (SELECT first_names[(1 + floor(random()*array_length(first_names,1)))::int] FROM params) AS fn,
         (SELECT last_names[(1 + floor(random()*array_length(last_names,1)))::int] FROM params) AS ln
) AS names;

-- Species and derived breed sampling
WITH species AS (
  SELECT unnest(ARRAY['Dog','Cat','Rabbit','Bird','Reptile']) AS s
)
INSERT INTO patients (
  owner_id, name, species, breed, age, gender, weight, status, assigned_doctor, handling_difficulty, created_at
)
SELECT
  ((g - 1) % :owners_count) + 1 AS owner_id,
  -- Pet name pool sampled by index
  (ARRAY['Buddy','Bella','Charlie','Luna','Max','Lucy','Cooper','Daisy','Rocky','Lily','Milo','Zoe','Bailey','Chloe','Toby','Nala','Sadie','Leo','Stella','Jack'])
    [1 + (floor(random()*20))::int] AS name,
  sp AS species,
  CASE sp
    WHEN 'Dog' THEN (ARRAY['Labrador Retriever','Golden Retriever','German Shepherd','Beagle','Poodle','Bulldog'])[1 + (floor(random()*6))::int]
    WHEN 'Cat' THEN (ARRAY['Siamese','Persian','Maine Coon','Bengal','Sphynx','Ragdoll'])[1 + (floor(random()*6))::int]
    WHEN 'Rabbit' THEN (ARRAY['Holland Lop','Netherland Dwarf','Mini Rex','Lionhead'])[1 + (floor(random()*4))::int]
    WHEN 'Bird' THEN (ARRAY['Parakeet','Cockatiel','Lovebird','Canary'])[1 + (floor(random()*4))::int]
    WHEN 'Reptile' THEN (ARRAY['Bearded Dragon','Leopard Gecko','Corn Snake','Ball Python'])[1 + (floor(random()*4))::int]
  END AS breed,
  (1 + floor(random()*14))::int AS age,
  (ARRAY['Male','Female'])[1 + (floor(random()*2))::int] AS gender,
  round(((5 + random()*100)::numeric), 2) AS weight,
  CASE WHEN random() < 0.1 THEN 'inactive' ELSE 'active' END AS status,
  (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS assigned_doctor,
  (ARRAY['easy','medium','hard'])[1 + (floor(random()*3))::int] AS handling_difficulty,
  now() - (random()*interval '365 days') AS created_at
FROM generate_series(1, :patients_count) AS gs(g)
CROSS JOIN LATERAL (
  -- Weighted species distribution (approx: Dog 45%, Cat 40%, others 15%)
  SELECT CASE
    WHEN r < 0.45 THEN 'Dog'
    WHEN r < 0.85 THEN 'Cat'
    WHEN r < 0.90 THEN 'Rabbit'
    WHEN r < 0.95 THEN 'Bird'
    ELSE 'Reptile'
  END AS sp
  FROM (SELECT random() AS r) t
) pick;

-- Indexes to support common access patterns
DROP INDEX IF EXISTS idx_patients_created_at;
DROP INDEX IF EXISTS idx_patients_owner_created;
DROP INDEX IF EXISTS idx_owners_created_at;

CREATE INDEX idx_patients_created_at ON patients (created_at DESC);
CREATE INDEX idx_patients_owner_created ON patients (owner_id, created_at DESC);
CREATE INDEX idx_owners_created_at ON owners (created_at DESC);

ANALYZE owners;
ANALYZE patients;

\echo Done. Inserted :owners_count owners and :patients_count patients.
