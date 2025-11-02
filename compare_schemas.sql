-- Schema Comparison Script
-- Compare webpay_master_dev with webpay_master_uat
-- Run this on webpay_master_dev database

-- 1. Tables comparison - find tables that exist in DEV but not in UAT
SELECT 'Tables only in DEV (need to check UAT):' as comparison_type;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name NOT IN (
    SELECT table_name
    FROM dblink('dbname=webpay_master_uat user=postgres password=postgres host=127.0.0.1 port=5435',
                'SELECT table_name FROM information_schema.tables WHERE table_schema = ''public'' AND table_type = ''BASE TABLE''')
    AS t(table_name text)
  )
ORDER BY table_name;

-- 2. Tables only in UAT but not in DEV
SELECT 'Tables only in UAT (older version?):' as comparison_type;
SELECT table_name
FROM dblink('dbname=webpay_master_uat user=postgres password=postgres host=127.0.0.1 port=5435',
            'SELECT table_name FROM information_schema.tables WHERE table_schema = ''public'' AND table_type = ''BASE TABLE''')
AS t(table_name text)
WHERE table_name NOT IN (
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
)
ORDER BY table_name;

-- 3. Column differences for common tables
SELECT 'Column differences in common tables:' as comparison_type;

WITH dev_columns AS (
  SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
  FROM information_schema.columns
  WHERE table_schema = 'public'
),
uat_columns AS (
  SELECT * FROM dblink('dbname=webpay_master_uat user=postgres password=postgres host=127.0.0.1 port=5435',
    'SELECT table_name, column_name, data_type, is_nullable, column_default
     FROM information_schema.columns
     WHERE table_schema = ''public''')
  AS t(table_name text, column_name text, data_type text, is_nullable text, column_default text)
)
SELECT
  COALESCE(d.table_name, u.table_name) as table_name,
  COALESCE(d.column_name, u.column_name) as column_name,
  d.data_type as dev_data_type,
  u.data_type as uat_data_type,
  CASE
    WHEN d.column_name IS NULL THEN 'Missing in DEV'
    WHEN u.column_name IS NULL THEN 'Missing in UAT'
    WHEN d.data_type != u.data_type THEN 'Type mismatch'
    WHEN d.is_nullable != u.is_nullable THEN 'Nullable mismatch'
    ELSE 'Other difference'
  END as difference_type
FROM dev_columns d
FULL OUTER JOIN uat_columns u
  ON d.table_name = u.table_name
  AND d.column_name = u.column_name
WHERE (d.column_name IS NULL OR u.column_name IS NULL)
   OR d.data_type != u.data_type
   OR d.is_nullable != u.is_nullable
ORDER BY table_name, column_name;

-- 4. Index differences
SELECT 'Index differences:' as comparison_type;

WITH dev_indexes AS (
  SELECT
    tablename,
    indexname,
    indexdef
  FROM pg_indexes
  WHERE schemaname = 'public'
),
uat_indexes AS (
  SELECT * FROM dblink('dbname=webpay_master_uat user=postgres password=postgres host=127.0.0.1 port=5435',
    'SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = ''public''')
  AS t(tablename text, indexname text, indexdef text)
)
SELECT
  COALESCE(d.tablename, u.tablename) as table_name,
  COALESCE(d.indexname, u.indexname) as index_name,
  CASE
    WHEN d.indexname IS NULL THEN 'Missing in DEV'
    WHEN u.indexname IS NULL THEN 'Missing in UAT'
    ELSE 'Definition mismatch'
  END as difference_type
FROM dev_indexes d
FULL OUTER JOIN uat_indexes u
  ON d.indexname = u.indexname
WHERE (d.indexname IS NULL OR u.indexname IS NULL)
   OR d.indexdef != u.indexdef
ORDER BY table_name, index_name;

-- 5. Schema version from migrations
SELECT 'Schema version (schema_info table):' as comparison_type;
SELECT 'DEV version:' as db, version FROM schema_info
UNION ALL
SELECT 'UAT version:' as db, version
FROM dblink('dbname=webpay_master_uat user=postgres password=postgres host=127.0.0.1 port=5435',
            'SELECT version FROM schema_info')
AS t(version integer);
