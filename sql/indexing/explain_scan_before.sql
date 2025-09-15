-- KR: 인덱스 적용 전 실행 계획 측정
-- EN: Measure execution plan before adding index

-- Ensure table exists (for first-time runs)
CREATE TABLE IF NOT EXISTS db_probes (
  id BIGSERIAL PRIMARY KEY,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

ANALYZE db_probes;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, created_at
FROM db_probes
ORDER BY created_at DESC
LIMIT 50;
