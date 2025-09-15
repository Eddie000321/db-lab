-- Seed Prisma tables directly via SQL (Owner, Patient, MedicalRecord, Appointment, Bill, User)
-- Usage (host):
--   psql $DATABASE_URL \
--     -v owners_count=1000 \
--     -v patients_per_owner=2 \
--     -v records_per_patient=3 \
--     -v appts_per_patient=1 \
--     -v bills_per_patient=1 \
--     -f sql/seed/seed_prisma_all.sql
-- Usage (Docker):
--   docker compose exec -e PGPASSWORD=password -T db psql -U user -d mydb \
--     -v owners_count=1000 -v patients_per_owner=2 -v records_per_patient=3 -v appts_per_patient=1 -v bills_per_patient=1 \
--     -f - < sql/seed/seed_prisma_all.sql

\set ON_ERROR_STOP on
\echo Seeding Prisma tables (Owner/Patient/MedicalRecord/Appointment/Bill/User)...

-- Defaults if not provided by -v
\if :{?owners_count} \else \set owners_count 1000 \endif
\if :{?patients_per_owner} \else \set patients_per_owner 2 \endif
\if :{?records_per_patient} \else \set records_per_patient 3 \endif
\if :{?appts_per_patient} \else \set appts_per_patient 1 \endif
\if :{?bills_per_patient} \else \set bills_per_patient 1 \endif

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Clean existing data (handle FKs)
TRUNCATE TABLE "Bill","Appointment","MedicalRecord","Patient","Owner","User" RESTART IDENTITY CASCADE;

-- 0) Users (optional for completeness; runtime auth remains in-memory)
INSERT INTO "User" (id, email, username, "firstName", "lastName", password, roles, "createdAt", "updatedAt") VALUES
  ('c'||encode(gen_random_bytes(12),'hex'), 'admin@vetchart.com', 'admin', 'Admin', 'User', 'hashed', ARRAY['admin','veterinarian'], now(), now()),
  ('c'||encode(gen_random_bytes(12),'hex'), 'vet@vetchart.com',   'vet',   'Sarah', 'Wilson', 'hashed', ARRAY['veterinarian'], now(), now()),
  ('c'||encode(gen_random_bytes(12),'hex'), 'staff@vetchart.com', 'staff', 'Clinic','Staff',  'hashed', ARRAY['staff'], now(), now());

-- Temp table to keep mapping from ordinal -> id
CREATE TEMP TABLE tmp_owner (g int, id text);
INSERT INTO tmp_owner (g, id)
SELECT g, 'c'||encode(gen_random_bytes(12),'hex')
FROM generate_series(1, :owners_count) AS gs(g);

-- 1) Owners
WITH params AS (
  SELECT
    ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','William','Elizabeth','David','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Charles','Karen'] AS first_names,
    ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'] AS last_names
)
INSERT INTO "Owner" (id, "firstName", "lastName", email, phone, address, notes, "createdAt", "updatedAt")
SELECT
  o.id,
  (SELECT first_names[1 + floor(random()*array_length(first_names,1))::int] FROM params) AS firstName,
  (SELECT last_names[1 + floor(random()*array_length(last_names,1))::int]  FROM params) AS lastName,
  'seed_'||o.g||'_'||floor(random()*100000)::text||'@example.com' AS email,
  '('||lpad(((random()*900)::int + 100)::text,3,'0')||') '||lpad(((random()*900)::int + 100)::text,3,'0')||'-'||lpad(((random()*9000)::int + 1000)::text,4,'0') AS phone,
  ((o.g % 9999) + 1)::text || ' Main St, Springfield, ST ' || lpad(((o.g % 99999) + 1)::text,5,'0') AS address,
  CASE WHEN random() < 0.2 THEN 'Prefers morning appointments' ELSE NULL END AS notes,
  now() - (random()*interval '365 days') AS created_at
FROM tmp_owner o;

-- Temp patients map
CREATE TEMP TABLE tmp_patient (id text, owner_id text);

-- 2) Patients
WITH species AS (
  SELECT unnest(ARRAY['Dog','Cat','Rabbit','Bird','Reptile']) AS s
)
INSERT INTO "Patient" (id, name, species, breed, age, gender, weight, "weightUnit", "ownerId", "assignedDoctor", status, "handlingDifficulty", "createdAt", "updatedAt")
SELECT
  p.id,
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
  (5 + random()*100) AS weight,
  'lbs' AS weightUnit,
  o.id AS ownerId,
  (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS assignedDoctor,
  CASE WHEN random() < 0.1 THEN 'inactive' ELSE 'active' END AS status,
  (ARRAY['easy','medium','hard'])[1 + (floor(random()*3))::int] AS handlingDifficulty,
  now() - (random()*interval '365 days') AS created_at,
  now() AS updated_at
FROM tmp_owner o
CROSS JOIN LATERAL (
  SELECT 'c'||encode(gen_random_bytes(12),'hex') AS id
) p
CROSS JOIN LATERAL (
  SELECT CASE
    WHEN r < 0.45 THEN 'Dog'
    WHEN r < 0.85 THEN 'Cat'
    WHEN r < 0.90 THEN 'Rabbit'
    WHEN r < 0.95 THEN 'Bird'
    ELSE 'Reptile'
  END AS sp FROM (SELECT random() AS r) t
) pick
CROSS JOIN generate_series(1, :patients_per_owner) per_owner;

-- Capture patient->owner mapping
INSERT INTO tmp_patient (id, owner_id)
SELECT id, "ownerId" FROM "Patient";

-- 3) Medical Records
WITH per_patient AS (
  SELECT tp.id AS pid FROM tmp_patient tp
)
INSERT INTO "MedicalRecord" (id, "patientId", "visitDate", "recordType", symptoms, diagnosis, treatment, notes, veterinarian, "createdAt", "updatedAt")
SELECT
  'c'||encode(gen_random_bytes(12),'hex') AS id,
  pp.pid AS patientId,
  now() - (random()*interval '365 days') AS visitDate,
  (ARRAY['vaccine','surgery','treatment','dental'])[1 + (floor(random()*4))::int] AS recordType,
  (ARRAY['Limping front leg','Excessive scratching','Vomiting 2 days','Annual wellness check','Dental cleaning follow-up','Skin irritation','Loss of appetite','Lethargy'])
     [1 + (floor(random()*8))::int] AS symptoms,
  (ARRAY['Sprain','Ear mites','Gastroenteritis','Healthy','Dermatitis','Dental plaque'])
     [1 + (floor(random()*6))::int] AS diagnosis,
  (ARRAY['Rest + anti-inflammatory','Ear drops 10 days','Bland diet + probiotics','DHPP booster','Antibiotics 7 days'])
     [1 + (floor(random()*5))::int] AS treatment,
  CASE WHEN random() < 0.5 THEN 'Recheck in 1-2 weeks' ELSE NULL END AS notes,
  (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS veterinarian,
  now() - (random()*interval '365 days') AS created_at,
  now() - (random()*interval '365 days') AS updated_at
FROM per_patient pp
CROSS JOIN generate_series(1, :records_per_patient) per_rec;

-- 4) Appointments
WITH per_patient AS (
  SELECT tp.id AS pid FROM tmp_patient tp
)
INSERT INTO "Appointment" (id, "patientId", date, time, duration, reason, status, notes, veterinarian, "createdAt", "updatedAt")
SELECT
  'c'||encode(gen_random_bytes(12),'hex') AS id,
  pp.pid AS patientId,
  now() - (random()*interval '90 days') AS date,
  LPAD((8 + (random()*10)::int)::text,2,'0')||':'||LPAD((ARRAY[0,15,30,45])[1 + (floor(random()*4))::int]::text,2,'0') AS time,
  (ARRAY[15,20,30,45,60])[1 + (floor(random()*5))::int] AS duration,
  (ARRAY['Wellness exam','Vaccination','Follow-up','Surgery consult','Dental cleaning'])[1 + (floor(random()*5))::int] AS reason,
  (ARRAY['scheduled','completed','cancelled','no-show','scheduled','completed'])[1 + (floor(random()*6))::int] AS status,
  CASE WHEN random() < 0.3 THEN 'Handle gently' ELSE NULL END AS notes,
  (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS veterinarian,
  now() - (random()*interval '120 days') AS created_at,
  now() - (random()*interval '120 days') AS updated_at
FROM per_patient pp
CROSS JOIN generate_series(1, :appts_per_patient) per_appt;

-- 5) Bills (items as JSONB; medicalRecordIds as text[])
CREATE SEQUENCE IF NOT EXISTS bill_number_seq;

WITH per_patient AS (
  SELECT tp.id AS pid, tp.owner_id AS owner_id FROM tmp_patient tp
),
base AS (
  SELECT
    pp.pid,
    pp.owner_id,
    gs.i AS n
  FROM per_patient pp
  CROSS JOIN LATERAL generate_series(1, :bills_per_patient) AS gs(i)
),
lines AS (
  SELECT
    b.pid,
    b.owner_id,
    b.n,
    jsonb_agg(jsonb_build_object(
      'id', idx::text,
      'description', (ARRAY['Exam','Vaccination','Lab Test','Medication','Procedure'])[1 + (floor(random()*5))::int],
      'quantity', qty,
      'unitPrice', unit,
      'totalPrice', ROUND((qty*unit)::numeric, 2)
    )) AS items,
    ROUND(SUM(qty*unit)::numeric, 2) AS subtotal
  FROM (
    SELECT
      b.pid,
      b.owner_id,
      b.n,
      generate_series(1, (1 + (random()*3)::int)) AS idx,
      (1 + (random()*1)::int) AS qty,
      ROUND( (25 + random()*120)::numeric, 2) AS unit
    FROM base b
  ) x
  GROUP BY x.pid, x.owner_id, x.n
)
INSERT INTO "Bill" (
  id, "billNumber", "ownerId", "patientId", "appointmentId", "medicalRecordIds", items, subtotal, tax, "totalAmount", status, "billDate", "dueDate", notes, "createdAt", "updatedAt"
)
SELECT
  'c'||encode(gen_random_bytes(12),'hex') AS id,
  'BILL-'||LPAD(nextval('bill_number_seq')::text, 6, '0') AS billNumber,
  l.owner_id AS ownerId,
  l.pid AS patientId,
  (
    SELECT a.id FROM "Appointment" a WHERE a."patientId" = l.pid ORDER BY random() LIMIT 1
  ) AS appointmentId,
  (
    SELECT ARRAY(SELECT mr.id FROM "MedicalRecord" mr WHERE mr."patientId" = l.pid ORDER BY mr."visitDate" DESC LIMIT (1 + (random()*3)::int))
  ) AS medicalRecordIds,
  l.items,
  l.subtotal::float AS subtotal,
  ROUND((l.subtotal * 0.08), 2)::float AS tax,
  ROUND((l.subtotal * 1.08), 2)::float AS totalAmount,
  (ARRAY['draft','sent','paid','overdue','cancelled','sent','paid'])[1 + (floor(random()*7))::int] AS status,
  now() - (random()*interval '120 days') AS billDate,
  now() + (random()*interval '30 days')  AS dueDate,
  CASE WHEN random() < 0.2 THEN 'Pay within 30 days' ELSE NULL END AS notes,
  now() - (random()*interval '120 days') AS created_at,
  now() - (random()*interval '120 days') AS updated_at;

ANALYZE "Owner";
ANALYZE "Patient";
ANALYZE "MedicalRecord";
ANALYZE "Appointment";
ANALYZE "Bill";

\echo Done. Inserted data into Prisma tables.
