-- Minimal Prisma-like schema DDL (no migration history)
-- Creates the tables used by seed scripts and UI queries.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop existing (DANGER in dev)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name IN ('Bill','Appointment','MedicalRecord','Patient','Owner','User')) THEN
    EXECUTE 'TRUNCATE TABLE "Bill","Appointment","MedicalRecord","Patient","Owner","User" RESTART IDENTITY CASCADE';
  END IF;
END $$;

-- User
CREATE TABLE IF NOT EXISTS "User" (
  id           text PRIMARY KEY,
  email        text NOT NULL UNIQUE,
  username     text NOT NULL UNIQUE,
  "firstName"  text NOT NULL,
  "lastName"   text NOT NULL,
  password     text NOT NULL,
  roles        text[] NOT NULL,
  "createdAt"  timestamptz NOT NULL DEFAULT now(),
  "updatedAt"  timestamptz NOT NULL DEFAULT now(),
  "deletedAt"  timestamptz
);

-- Owner
CREATE TABLE IF NOT EXISTS "Owner" (
  id           text PRIMARY KEY,
  "firstName"  text NOT NULL,
  "lastName"   text NOT NULL,
  email        text NOT NULL UNIQUE,
  phone        text NOT NULL,
  address      text NOT NULL,
  notes        text,
  "createdAt"  timestamptz NOT NULL DEFAULT now(),
  "updatedAt"  timestamptz NOT NULL DEFAULT now(),
  "deletedAt"  timestamptz
);

-- Patient
CREATE TABLE IF NOT EXISTS "Patient" (
  id                   text PRIMARY KEY,
  name                 text NOT NULL,
  species              text NOT NULL,
  breed                text NOT NULL,
  age                  int  NOT NULL,
  gender               text NOT NULL,
  weight               double precision NOT NULL,
  "weightUnit"         text DEFAULT 'lbs',
  status               text NOT NULL DEFAULT 'active',
  "assignedDoctor"     text,
  "handlingDifficulty" text,
  "ownerId"            text NOT NULL,
  "createdAt"          timestamptz NOT NULL DEFAULT now(),
  "updatedAt"          timestamptz NOT NULL DEFAULT now(),
  "deletedAt"          timestamptz,
  CONSTRAINT fk_patient_owner FOREIGN KEY ("ownerId") REFERENCES "Owner"(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_patient_owner_created ON "Patient"("ownerId","createdAt" DESC);

-- MedicalRecord
CREATE TABLE IF NOT EXISTS "MedicalRecord" (
  id           text PRIMARY KEY,
  "patientId"  text NOT NULL,
  "visitDate"  timestamptz NOT NULL,
  "recordType" text NOT NULL DEFAULT 'treatment',
  symptoms     text NOT NULL,
  diagnosis    text NOT NULL,
  treatment    text NOT NULL,
  notes        text,
  "veterinarianId"   text,
  "veterinarianName" text NOT NULL,
  "createdAt"  timestamptz NOT NULL DEFAULT now(),
  "updatedAt"  timestamptz NOT NULL DEFAULT now(),
  "deletedAt"  timestamptz,
  CONSTRAINT fk_record_patient FOREIGN KEY ("patientId") REFERENCES "Patient"(id) ON DELETE RESTRICT,
  CONSTRAINT fk_record_veterinarian FOREIGN KEY ("veterinarianId") REFERENCES "User"(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_record_patient_visit ON "MedicalRecord"("patientId","visitDate" DESC);
CREATE INDEX IF NOT EXISTS idx_record_vet_visit ON "MedicalRecord"("veterinarianId","visitDate" DESC);

-- Appointment
CREATE TABLE IF NOT EXISTS "Appointment" (
  id           text PRIMARY KEY,
  "patientId"  text NOT NULL,
  date         timestamptz NOT NULL,
  time         text NOT NULL,
  duration     int NOT NULL,
  reason       text NOT NULL,
  status       text NOT NULL DEFAULT 'scheduled',
  notes        text,
  "veterinarianId"   text,
  "veterinarianName" text NOT NULL,
  "createdAt"  timestamptz NOT NULL DEFAULT now(),
  "updatedAt"  timestamptz NOT NULL DEFAULT now(),
  "deletedAt"  timestamptz,
  CONSTRAINT fk_appt_patient FOREIGN KEY ("patientId") REFERENCES "Patient"(id) ON DELETE RESTRICT,
  CONSTRAINT fk_appt_veterinarian FOREIGN KEY ("veterinarianId") REFERENCES "User"(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_appt_date ON "Appointment"(date DESC);
CREATE INDEX IF NOT EXISTS idx_appt_vet_date ON "Appointment"("veterinarianId", date DESC);

-- Bill
CREATE TABLE IF NOT EXISTS "Bill" (
  id               text PRIMARY KEY,
  "billNumber"     text NOT NULL UNIQUE,
  "ownerId"        text NOT NULL,
  "patientId"      text NOT NULL,
  "appointmentId"  text,
  "medicalRecordIds" text[] NOT NULL,
  items            jsonb NOT NULL,
  subtotal         double precision NOT NULL,
  tax              double precision NOT NULL,
  "totalAmount"    double precision NOT NULL,
  status           text NOT NULL DEFAULT 'draft',
  "billDate"       timestamptz NOT NULL DEFAULT now(),
  "dueDate"        timestamptz NOT NULL,
  notes            text,
  "createdAt"      timestamptz NOT NULL DEFAULT now(),
  "updatedAt"      timestamptz NOT NULL DEFAULT now(),
  "deletedAt"      timestamptz,
  CONSTRAINT fk_bill_owner      FOREIGN KEY ("ownerId")       REFERENCES "Owner"(id)      ON DELETE RESTRICT,
  CONSTRAINT fk_bill_patient    FOREIGN KEY ("patientId")     REFERENCES "Patient"(id)    ON DELETE RESTRICT,
  CONSTRAINT fk_bill_appt       FOREIGN KEY ("appointmentId") REFERENCES "Appointment"(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_bill_created ON "Bill"("createdAt" DESC);

-- Done
