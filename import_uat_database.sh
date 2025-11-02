#!/bin/bash
#
# UAT Database Import and Schema Comparison Script
# Purpose: Import UAT AWS dump and compare schemas with current dev database
#

set -e  # Exit on error

# Configuration
PG_HOST="127.0.0.1"
PG_PORT="5435"
PG_USER="postgres"
PG_PASSWORD="postgres"
DEV_DB="webpay_master_dev"
UAT_DB="webpay_master_uat"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if dump file is provided
if [ -z "$1" ]; then
    log_error "Usage: $0 <path_to_uat_dump.sql>"
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/webpay_uat_dump.sql"
    echo ""
    exit 1
fi

DUMP_FILE="$1"

# Check if dump file exists
if [ ! -f "$DUMP_FILE" ]; then
    log_error "Dump file not found: $DUMP_FILE"
    exit 1
fi

log_info "Starting UAT database import process..."
echo ""

# Step 1: Create UAT database
log_info "Step 1: Creating database '$UAT_DB'..."
PGPASSWORD=$PG_PASSWORD dropdb -h $PG_HOST -p $PG_PORT -U $PG_USER --if-exists $UAT_DB 2>/dev/null || true
PGPASSWORD=$PG_PASSWORD createdb -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB
log_success "Database '$UAT_DB' created"
echo ""

# Step 2: Import dump
log_info "Step 2: Importing UAT dump (this may take a while)..."

# Detect dump format
if [[ "$DUMP_FILE" == *.tar ]]; then
    log_info "Detected tar format dump (pg_dump -F t), using pg_restore..."
    PGPASSWORD=$PG_PASSWORD pg_restore -h $PG_HOST -p $PG_PORT -U $PG_USER -d $UAT_DB -v "$DUMP_FILE" 2>&1 | grep -v "^pg_restore: processing"
elif [[ "$DUMP_FILE" == *.gz ]]; then
    log_info "Detected gzip compressed SQL file, decompressing..."
    gunzip -c "$DUMP_FILE" | PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB > /dev/null 2>&1
elif [[ "$DUMP_FILE" == *.custom || "$DUMP_FILE" == *.dump ]]; then
    log_info "Detected custom format dump (pg_dump -Fc), using pg_restore..."
    PGPASSWORD=$PG_PASSWORD pg_restore -h $PG_HOST -p $PG_PORT -U $PG_USER -d $UAT_DB -v "$DUMP_FILE" 2>&1 | grep -v "^pg_restore: processing"
else
    log_info "Detected plain SQL format, using psql..."
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB < "$DUMP_FILE" > /dev/null 2>&1
fi

log_success "UAT dump imported successfully"
echo ""

# Step 3: Get schema versions
log_info "Step 3: Checking schema versions..."
DEV_VERSION=$(PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $DEV_DB -t -c "SELECT version FROM schema_info;" | tr -d ' ')
UAT_VERSION=$(PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB -t -c "SELECT version FROM schema_info;" | tr -d ' ')

echo "  DEV schema version: $DEV_VERSION"
echo "  UAT schema version: $UAT_VERSION"

if [ "$DEV_VERSION" -eq "$UAT_VERSION" ]; then
    log_success "Schema versions match!"
else
    log_warning "Schema versions differ! Migration needed."
    MIGRATION_NEEDED=true
fi
echo ""

# Step 4: Export schema info to files
log_info "Step 4: Exporting schema information for comparison..."

# DEV schema
PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $DEV_DB > dev_schema.txt 2>&1 <<EOF
-- Tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Columns
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
EOF

# UAT schema
PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB > uat_schema.txt 2>&1 <<EOF
-- Tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Columns
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
EOF

log_success "Schema info exported to dev_schema.txt and uat_schema.txt"
echo ""

# Step 5: Compare schemas with diff
log_info "Step 5: Comparing schemas..."
if diff -u dev_schema.txt uat_schema.txt > schema_diff.txt 2>&1; then
    log_success "Schemas are identical!"
    rm -f schema_diff.txt
else
    log_warning "Schema differences found! See schema_diff.txt for details"
    echo ""
    log_info "Showing first 50 lines of differences:"
    head -50 schema_diff.txt
fi
echo ""

# Step 6: Check row counts
log_info "Step 6: Comparing table row counts..."
echo ""
echo "  Table Name                  | DEV Rows  | UAT Rows  | Difference"
echo "  --------------------------- | --------- | --------- | ----------"

PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $DEV_DB -t -c "
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
" | while read -r table; do
    if [ -n "$table" ]; then
        dev_count=$(PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $DEV_DB -t -c "SELECT COUNT(*) FROM $table;" | tr -d ' ')
        uat_count=$(PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER $UAT_DB -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ') || uat_count="N/A"
        diff=$((uat_count - dev_count))
        printf "  %-27s | %9s | %9s | %+10s\n" "$table" "$dev_count" "$uat_count" "$diff"
    fi
done
echo ""

# Step 7: Migration recommendation
log_info "Step 7: Migration Analysis..."
echo ""

if [ -n "$MIGRATION_NEEDED" ]; then
    log_warning "UAT database needs migration from version $UAT_VERSION to $DEV_VERSION"
    echo ""
    echo "  To migrate UAT database, run these migrations:"
    echo ""

    # List missing migrations
    for i in $(seq $((UAT_VERSION + 1)) $DEV_VERSION); do
        migration_file=$(ls -1 db/migrate/ | grep "^$(printf "%03d" $i)_" 2>/dev/null || echo "NOT FOUND")
        echo "    Migration $i: $migration_file"
    done

    echo ""
    echo "  Run migrations with:"
    echo "    WP_ENV=development WP_DATABASE_NAME=$UAT_DB bundle exec rake db:migrate"
else
    log_success "UAT database is up-to-date! No migrations needed."
fi
echo ""

# Summary
log_info "===== Summary ====="
echo ""
echo "  DEV Database: $DEV_DB (version $DEV_VERSION)"
echo "  UAT Database: $UAT_DB (version $UAT_VERSION)"
echo ""
echo "  Files created:"
echo "    - dev_schema.txt  (DEV schema info)"
echo "    - uat_schema.txt  (UAT schema info)"
[ -f schema_diff.txt ] && echo "    - schema_diff.txt (schema differences)"
echo ""
echo "  To manually run migrations on UAT database:"
echo "    WP_ENV=development WP_DATABASE_NAME=$UAT_DB bundle exec rake db:migrate"
echo ""
echo "  To switch your application to use UAT database:"
echo "    Update .env: WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/$UAT_DB"
echo ""

log_success "UAT database import complete!"
