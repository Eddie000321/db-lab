-- KR: 인덱스 적용 후 실행 계획 측정
-- EN: Measure execution plan after adding index

ANALYZE db_probes;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, created_at
FROM db_probes
ORDER BY created_at DESC
LIMIT 50;
