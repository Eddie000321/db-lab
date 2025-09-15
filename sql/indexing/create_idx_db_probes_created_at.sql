-- KR: db_probes.created_at 기준 정렬 최적화를 위한 인덱스 생성
-- EN: Create index to optimize ORDER BY created_at on db_probes

-- Ensure table exists for local experiments (matches server ensureProbeTable)
CREATE TABLE IF NOT EXISTS db_probes (
  id BIGSERIAL PRIMARY KEY,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_db_probes_created_at ON db_probes (created_at DESC);
