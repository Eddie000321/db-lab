-- Consistent seeder for Prisma tables with constraints described:
-- - owners_count owners (default 1000)
-- - patients_per_owner patients per owner (default 2)
-- - each patient has between min_records..max_records medical records (defaults 1..50)
-- - appointments may or may not exist; when they exist, they correspond to a record (same datetime)
-- - one bill per medical record, referencing that record id and the matching appointment if present
--
-- Usage (host):
--   psql $DATABASE_URL \
--     -v owners_count=1000 -v patients_per_owner=2 -v min_records=1 -v max_records=50 -v appointment_prob=0.6 \
--     -f sql/seed/seed_prisma_consistent.sql
-- Usage (Docker):
--   docker compose exec -e PGPASSWORD=password -T db psql -U user -d mydb \
--     -v owners_count=1000 -v patients_per_owner=2 -v min_records=1 -v max_records=50 -v appointment_prob=0.6 \
--     -f - < sql/seed/seed_prisma_consistent.sql

\set ON_ERROR_STOP on
\echo Seeding Prisma tables with consistent appointments-bills-records...

-- Defaults
\if :{?owners_count} \else \set owners_count 1000 \endif
\if :{?patients_per_owner} \else \set patients_per_owner 2 \endif
\if :{?min_records} \else \set min_records 1 \endif
\if :{?max_records} \else \set max_records 50 \endif
\if :{?appointment_prob} \else \set appointment_prob 0.6 \endif

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Clean existing data
TRUNCATE TABLE "Bill","Appointment","MedicalRecord","Patient","Owner","User" RESTART IDENTITY CASCADE;

-- Users (optional)
INSERT INTO "User" (id, email, username, "firstName", "lastName", password, roles, "createdAt", "updatedAt") VALUES
  ('c'||encode(gen_random_bytes(12),'hex'), 'admin@vetchart.com', 'admin', 'Admin', 'User', 'hashed', ARRAY['admin','veterinarian'], now(), now()),
  ('c'||encode(gen_random_bytes(12),'hex'), 'vet@vetchart.com',   'vet',   'Sarah', 'Wilson', 'hashed', ARRAY['veterinarian'], now(), now()),
  ('c'||encode(gen_random_bytes(12),'hex'), 'staff@vetchart.com', 'staff', 'Clinic','Staff',  'hashed', ARRAY['staff'], now(), now());

-- Temp owners
CREATE TEMP TABLE tmp_owner (g int, id text);
INSERT INTO tmp_owner (g, id)
SELECT g, 'c'||encode(gen_random_bytes(12),'hex')
FROM generate_series(1, :owners_count) AS gs(g);

-- Owners
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
  now() - (random()*interval '365 days') AS created_at,
  now() AS updated_at
FROM tmp_owner o;

-- Temp patients
CREATE TEMP TABLE tmp_patient (id text, owner_id text);

-- Patients
WITH species AS (
  SELECT unnest(ARRAY['Dog','Cat','Rabbit','Bird','Reptile']) AS s
)
INSERT INTO "Patient" (id, name, species, breed, age, gender, weight, "weightUnit", "ownerId", "assignedDoctor", status, "handlingDifficulty", "createdAt", "updatedAt")
SELECT
  'c'||encode(gen_random_bytes(12),'hex') AS id,
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
  SELECT CASE
    WHEN r < 0.45 THEN 'Dog'
    WHEN r < 0.85 THEN 'Cat'
    WHEN r < 0.90 THEN 'Rabbit'
    WHEN r < 0.95 THEN 'Bird'
    ELSE 'Reptile'
  END AS sp FROM (SELECT random() AS r) t
) pick
CROSS JOIN generate_series(1, :patients_per_owner) per_owner;

-- Capture patient->owner
INSERT INTO tmp_patient (id, owner_id)
SELECT id, "ownerId" FROM "Patient";

-- Temp records based on random count per patient
CREATE TEMP TABLE tmp_record (id text, patient_id text, visit_dt timestamptz);
INSERT INTO tmp_record (id, patient_id, visit_dt)
SELECT 
  'c'||encode(gen_random_bytes(12),'hex') AS id,
  tp.id AS patient_id,
  now() - (random()*interval '365 days') AS visit_dt
FROM tmp_patient tp
CROSS JOIN LATERAL (
  SELECT ( (random() * ((:max_records)::int - (:min_records)::int + 1))::int + (:min_records)::int ) AS rec_count
) rc
CROSS JOIN LATERAL generate_series(1, rc.rec_count) gs(n);

-- Insert MedicalRecords from tmp_record
INSERT INTO "MedicalRecord" (id, "patientId", "visitDate", "recordType", symptoms, diagnosis, treatment, notes, veterinarian, "createdAt", "updatedAt")
SELECT
  tr.id,
  tr.patient_id,
  tr.visit_dt,
  (ARRAY['vaccine','surgery','treatment','dental'])[1 + (floor(random()*4))::int] AS recordType,
  (ARRAY['Limping front leg','Excessive scratching','Vomiting 2 days','Annual wellness check','Dental cleaning follow-up','Skin irritation','Loss of appetite','Lethargy'])
     [1 + (floor(random()*8))::int] AS symptoms,
  (ARRAY['Sprain','Ear mites','Gastroenteritis','Healthy','Dermatitis','Dental plaque'])
     [1 + (floor(random()*6))::int] AS diagnosis,
  (ARRAY['Rest + anti-inflammatory','Ear drops 10 days','Bland diet + probiotics','DHPP booster','Antibiotics 7 days'])
     [1 + (floor(random()*5))::int] AS treatment,
  CASE WHEN random() < 0.5 THEN 'Recheck in 1-2 weeks' ELSE NULL END AS notes,
  (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS veterinarian,
  tr.visit_dt,
  tr.visit_dt
FROM tmp_record tr;

-- Appointments: subset of records get one matching appointment
CREATE TEMP TABLE tmp_appt AS
WITH ins AS (
  INSERT INTO "Appointment" (id, "patientId", date, time, duration, reason, status, notes, veterinarian, "createdAt", "updatedAt")
  SELECT
    'c'||encode(gen_random_bytes(12),'hex') AS id,
    tr.patient_id AS "patientId",
    tr.visit_dt AS date,
    to_char(tr.visit_dt, 'HH24:MI') AS time,
    (ARRAY[15,20,30,45,60])[1 + (floor(random()*5))::int] AS duration,
    (ARRAY['Wellness exam','Vaccination','Follow-up','Surgery consult','Dental cleaning'])[1 + (floor(random()*5))::int] AS reason,
    (CASE WHEN tr.visit_dt < now() THEN (ARRAY['completed','completed','completed','no-show'])[1 + (floor(random()*4))::int]
          ELSE 'scheduled' END) AS status,
    CASE WHEN random() < 0.3 THEN 'Handle gently' ELSE NULL END AS notes,
    (ARRAY['J Han','J Lee','Sarah Wilson','Michael Brown'])[1 + (floor(random()*4))::int] AS veterinarian,
    tr.visit_dt,
    tr.visit_dt
  FROM tmp_record tr
  WHERE random() < :appointment_prob
  RETURNING id, "patientId", date
)
SELECT "patientId" AS patient_id, date AS visit_dt, id AS appt_id FROM ins;

-- Bills: one per record, referencing that record and the matching appointment if any
CREATE SEQUENCE IF NOT EXISTS bill_number_seq;

WITH linebase AS (
  SELECT tr.id AS rec_id
  FROM tmp_record tr
),
lines AS (
  SELECT
    x.rec_id,
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
      lb.rec_id,
      generate_series(1, 1 + (random()*3)::int) AS idx,
      (1 + (random()*1)::int) AS qty,
      ROUND( (25 + random()*120)::numeric, 2) AS unit
    FROM linebase lb
  ) x
  GROUP BY x.rec_id
)
INSERT INTO "Bill" (
  id, "billNumber", "ownerId", "patientId", "appointmentId", "medicalRecordIds", items, subtotal, tax, "totalAmount", status, "billDate", "dueDate", notes, "createdAt", "updatedAt"
)
SELECT
  'c'||encode(gen_random_bytes(12),'hex') AS id,
  'BILL-'||LPAD(nextval('bill_number_seq')::text, 6, '0') AS billNumber,
  tp.owner_id AS "ownerId",
  tr.patient_id AS "patientId",
  ta.appt_id AS "appointmentId",
  ARRAY[tr.id]::text[] AS "medicalRecordIds",
  l.items,
  l.subtotal::float AS subtotal,
  ROUND((l.subtotal * 0.08), 2)::float AS tax,
  ROUND((l.subtotal * 1.08), 2)::float AS "totalAmount",
  (ARRAY['draft','sent','paid','overdue','cancelled','sent','paid'])[1 + (floor(random()*7))::int] AS status,
  tr.visit_dt AS "billDate",
  tr.visit_dt + interval '30 days' AS "dueDate",
  CASE WHEN random() < 0.2 THEN 'Pay within 30 days' ELSE NULL END AS notes,
  tr.visit_dt AS "createdAt",
  tr.visit_dt AS "updatedAt"
FROM tmp_record tr
JOIN tmp_patient tp ON tp.id = tr.patient_id
LEFT JOIN tmp_appt ta ON ta.patient_id = tr.patient_id AND ta.visit_dt = tr.visit_dt
JOIN lines l ON l.rec_id = tr.id;

ANALYZE "Owner";
ANALYZE "Patient";
ANALYZE "MedicalRecord";
ANALYZE "Appointment";
ANALYZE "Bill";

\echo Done. Prisma tables seeded consistently.
