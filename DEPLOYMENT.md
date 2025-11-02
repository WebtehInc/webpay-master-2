# WebPay Master - Deployment Guide

**Version**: 2.0
**Date**: 2025-11-02
**Ruby**: 3.3.0
**Database**: PostgreSQL 15+ (Compatible with PostgreSQL 13.20+)
**Schema Version**: 135 migrations

---

## Table of Contents

1. [Fresh Installation (New Developer)](#fresh-installation-new-developer)
2. [UAT Migration (Existing Instance)](#uat-migration-existing-instance)
3. [Production Deployment](#production-deployment)
4. [Common Issues](#common-issues)
5. [Testing Checklist](#testing-checklist)

---

## Fresh Installation (New Developer)

This guide is for **Developer 2**, **QA testers**, or anyone setting up WebPay Master from scratch.

### Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby 3.3.0** (use rbenv, rvm, or asdf)
- **PostgreSQL 15+** (or 13.20+)
- **Git**
- **Bundler** (`gem install bundler`)
- **Node.js & npm** (for webpay-spa frontend)

### Step 1: Install Ruby 3.3.0

```bash
# Using rbenv (recommended):
brew install rbenv ruby-build
rbenv install 3.3.0
rbenv global 3.3.0

# Verify Ruby version:
ruby -v
# Should output: ruby 3.3.0

# Install bundler:
gem install bundler
```

**Alternative**: Use rvm or asdf if you prefer.

### Step 2: Install PostgreSQL

```bash
# macOS (Homebrew):
brew install postgresql@15
brew services start postgresql@15

# Linux (Ubuntu/Debian):
sudo apt-get install postgresql-15 postgresql-contrib-15
sudo systemctl start postgresql

# Verify PostgreSQL is running:
psql --version
# Should output: psql (PostgreSQL) 15.x
```

**Default PostgreSQL Port**: 5432
**If you need custom port**: Use 5435 (see .env configuration below)

### Step 3: Clone Repository

```bash
# Clone from GitHub:
git clone https://github.com/WebtehInc/webpay-master-2.git webpay-master
cd webpay-master

# Or if using the local submodule structure:
cd /path/to/ClaudeAI/webpay-master/v2-current
```

### Step 4: Install Ruby Dependencies

```bash
# Ensure rbenv is initialized (add to .zshrc or .bashrc):
eval "$(rbenv init - zsh)"  # or bash

# Install gems:
bundle install
```

**Expected Output**:
```
Bundle complete! 48 Gemfile dependencies, XX gems now installed.
```

**Common Issue**: If `bundle install` fails due to `pg` gem:
```bash
# macOS (Homebrew PostgreSQL):
bundle config build.pg --with-pg-config=/opt/homebrew/bin/pg_config
bundle install
```

### Step 5: Configure Environment Variables

```bash
# Copy example .env file:
cp .env.example.txt .env

# Edit .env file:
nano .env  # or vim, code, etc.
```

**Required Environment Variables**:

```bash
# ENV type
WP_ENV=development

# Database URL
WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_master_dev

# SMTP (for emails - use mailcatcher for local dev)
WP_SMTP_HOST=localhost
WP_SMTP_PORT=1025

# SPA domain (adjust if using different port)
WP_SPA_HOST_URL='http://localhost:2222/#!'

# OTP settings
OTP_TTL=300

# JWT settings
JWT_KEY=dev_secret_key_12345
JWT_TTL=1800

# App settings
APP_NAME=WebPay
BANK_NAME=My Bank
DEFAULT_CURENCY=USD
DEFAULT_COUNTRY=US

# Core bank service (use mock for development)
CORE_BANK_SERVICE=fiserv
FISERV_CLIENT=mock
FISERV_URL=http://fiserv:12345/TEST/CRG.aspx

# Pagatinu (use mock for development)
PAGATINU_CLIENT=mock
PAGATINU_URL=http://pagatinu:12345/GatewayServiceASP.asmx
```

**Note**: For production, you'll need real SMTP credentials and service URLs.

### Step 6: Setup /etc/hosts (Optional but Recommended)

Add `webpay` hostname to `/etc/hosts`:

```bash
# Edit /etc/hosts:
sudo nano /etc/hosts

# Add this line:
127.0.0.1 webpay
```

**Why?**: Some configuration expects `webpay` hostname. If you skip this, use `127.0.0.1` or `localhost` instead.

### Step 7: Create and Migrate Database

```bash
# Create database:
createdb -h 127.0.0.1 -p 5432 -U postgres webpay_master_dev

# Run migrations:
WP_ENV=development bundle exec rake db:migrate

# Verify schema version:
psql -h 127.0.0.1 -p 5432 -U postgres webpay_master_dev -c "SELECT version FROM schema_info;"
```

**Expected Output**:
```
 version
---------
     135
(1 row)
```

**All 135 migrations should execute successfully.**

### Step 8: Seed Database (Optional)

```bash
# Load initial data (if seed task exists):
WP_ENV=development bundle exec rake db:seed

# Or manually create test users via console:
bundle exec rake console
```

**Note**: Check if `db/seeds.rb` exists. If not, you'll need to create test data manually or import UAT database (see UAT_DATABASE_IMPORT.md).

### Step 9: Install and Run Mailcatcher (Optional)

```bash
# Install mailcatcher gem:
gem install mailcatcher

# Run mailcatcher:
mailcatcher

# Access web UI:
open http://localhost:1080
```

**Why?**: Mailcatcher captures emails sent by the app (like OTP activation emails) without actually sending them.

### Step 10: Start WebPay Master Backend

```bash
# Start Puma server:
cd /path/to/webpay-master/v2-current
eval "$(rbenv init - zsh)"
WP_ENV=development RUBYOPT="-W0" puma -v -t 2:2 -b tcp://0.0.0.0:4444

# Alternative: Use rerun for auto-restart on file changes:
RUBYOPT="-W0" rerun -- puma -v -t 2:2 -b tcp://0.0.0.0:4444
```

**Expected Output**:
```
Puma starting in single mode...
* Version 6.4.3
* Min threads: 2, max threads: 2
* Environment: development
* Listening on tcp://0.0.0.0:4444
```

**Backend is now running on**: `http://localhost:4444`

### Step 11: Install and Run WebPay SPA (Frontend)

```bash
# Clone webpay-spa repository:
git clone https://github.com/WebtehInc/webpay-spa-2.git webpay-spa
cd webpay-spa

# Install dependencies:
npm install

# Start dev server:
npm run dev
```

**Expected Output**:
```
VITE v4.x.x ready in XXX ms
➜  Local:   http://localhost:2222/
```

**Frontend is now running on**: `http://localhost:2222`

### Step 12: Verify Installation

1. **Open browser**: `http://localhost:2222`
2. **You should see**: WebPay login page
3. **Test API**: `curl http://localhost:4444/health` (if health endpoint exists)

**Common Issue**: If you see CORS errors in browser console:
- Verify `WP_SPA_HOST_URL` in `.env` matches your frontend URL
- Check `config.ru` for CORS configuration

---

## UAT Migration (Existing Instance)

This guide is for **upgrading an existing UAT webpay-master instance** to the latest version.

### Scenario

You have a **running UAT instance** (e.g., on AWS, DigitalOcean, or on-premises) that needs to be updated with:
- New code changes (git pull)
- New database migrations
- New dependencies (bundle install)
- New environment variables

### Prerequisites

- **SSH access** to UAT server
- **Database backup** before migration
- **Downtime window** (5-15 minutes typical)

### Migration Steps

#### 1. Backup Current UAT Database

```bash
# SSH into UAT server:
ssh user@uat-server

# Create database backup:
pg_dump -h localhost -U postgres -p 5433 -F t webpay_production_2022 > /backup/webpay_uat_backup_$(date +%Y%m%d_%H%M%S).tar

# Verify backup was created:
ls -lh /backup/webpay_uat_backup_*.tar
```

**CRITICAL**: Do not proceed without a verified backup!

#### 2. Stop WebPay Master Service

```bash
# Stop Puma (adjust command based on your process manager):

# If using systemd:
sudo systemctl stop webpay-master

# If using Foreman:
sudo systemctl stop webpay-master-foreman

# If using manual process:
pkill -f puma

# Verify process stopped:
ps aux | grep puma
```

#### 3. Pull Latest Code from GitHub

```bash
# Navigate to webpay-master directory:
cd /var/www/webpay-master  # adjust path

# Check current branch:
git branch

# Pull latest changes:
git fetch origin
git pull origin master  # or your target branch

# Verify new commits:
git log -5 --oneline
```

#### 4. Update Ruby Dependencies

```bash
# Install/update gems:
bundle install --deployment --without development test

# Verify bundle is complete:
bundle check
```

**Note**: `--deployment` flag installs gems to `vendor/bundle` (recommended for production).

#### 5. Update Environment Variables

```bash
# Check if new environment variables were added:
diff .env .env.example.txt

# Update .env if needed:
nano .env

# Add any missing variables (check CHANGELOG.md or git commits)
```

**Common New Variables**:
- OTP_TTL (if OTP activation was added)
- JWT_KEY (if JWT authentication was added)
- New service URLs or API keys

#### 6. Run Database Migrations

```bash
# Check current schema version:
psql -h localhost -U postgres -p 5433 webpay_production_2022 -c "SELECT version FROM schema_info;"

# Run migrations:
WP_ENV=production \
WP_PROD_DATABASE_URL='postgres://postgres:password@localhost:5433/webpay_production_2022' \
bundle exec rake db:migrate

# Verify new schema version:
psql -h localhost -U postgres -p 5433 webpay_production_2022 -c "SELECT version FROM schema_info;"
```

**Expected Output**:
```
 version
---------
     135  # Should be latest version
(1 row)
```

#### 7. Precompile Assets (if applicable)

```bash
# If webpay-master serves static assets:
RAILS_ENV=production bundle exec rake assets:precompile  # adjust if using Roda

# Not always needed for API-only backends
```

#### 8. Restart WebPay Master Service

```bash
# Start Puma (adjust command based on your process manager):

# If using systemd:
sudo systemctl start webpay-master
sudo systemctl status webpay-master

# If using Foreman:
sudo systemctl start webpay-master-foreman

# If using manual process:
cd /var/www/webpay-master
WP_ENV=production RUBYOPT="-W0" puma -C puma.rb -b tcp://0.0.0.0:4444 &

# Verify process started:
ps aux | grep puma
```

#### 9. Verify UAT is Running

```bash
# Check service status:
curl -I http://localhost:4444/health  # or your health check endpoint

# Check logs:
tail -f /var/log/webpay-master/puma.log  # adjust path

# Check database connection:
psql -h localhost -U postgres -p 5433 webpay_production_2022 -c "SELECT COUNT(*) FROM users;"
```

#### 10. Test Critical Functionality

1. **Login** - Verify users can log in
2. **OTP Activation** - Test new user registration with OTP (if applicable)
3. **Transactions** - Test account transactions
4. **API Endpoints** - Test key API endpoints

**If any issues occur**:
```bash
# Rollback database (restore from backup):
pg_restore -h localhost -U postgres -p 5433 -d webpay_production_2022_rollback /backup/webpay_uat_backup_20251102_143000.tar

# Rollback code (git reset):
git reset --hard <previous-commit-hash>

# Restart service
sudo systemctl restart webpay-master
```

---

## Production Deployment

### Additional Considerations for Production

1. **Load Balancer Configuration**
   - Update Nginx/HAProxy config for new endpoints
   - SSL certificates (Let's Encrypt or commercial)
   - Health check endpoints

2. **Environment Variables**
   - Use **real SMTP credentials** (not localhost:1025)
   - Use **real service URLs** (Fiserv, Pagatinu, etc.)
   - Use **strong JWT_KEY** (generate with `openssl rand -hex 64`)
   - Set `WP_ENV=production`

3. **Database**
   - Use **managed PostgreSQL** (AWS RDS, DigitalOcean Managed DB)
   - Enable **automated backups** (daily minimum)
   - Use **connection pooling** (PgBouncer recommended)

4. **Monitoring**
   - Application Performance Monitoring (APM) - New Relic, Scout, Skylight
   - Error tracking - Sentry, Rollbar, Airbrake
   - Log aggregation - Splunk, Datadog, ELK stack

5. **Security**
   - **Never commit .env to git** (use .gitignore)
   - Use **environment-specific secrets** (Vault, AWS Secrets Manager)
   - Enable **database encryption at rest**
   - Use **HTTPS only** (enforce in Nginx/HAProxy)

6. **Scaling**
   - Use **Puma worker killer** (already configured in Gemfile)
   - Configure `PUMA_MAX_PROCESSES` and `PUMA_MAX_THREADS` in `.env`
   - Monitor memory usage and adjust worker count

7. **Deployment Automation**
   - Use **Capistrano**, **Ansible**, or **GitHub Actions** for automated deployments
   - Run database migrations in a **zero-downtime** manner (use migration flags)
   - Use **blue-green deployment** or **rolling updates**

---

## Common Issues

### Issue 1: `bundle install` Fails on `pg` Gem

**Symptoms**:
```
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.
Can't find the 'libpq-fe.h header
```

**Solution**:
```bash
# macOS (Homebrew PostgreSQL):
bundle config build.pg --with-pg-config=/opt/homebrew/bin/pg_config

# Linux (Ubuntu/Debian):
sudo apt-get install libpq-dev
```

### Issue 2: Database Connection Refused

**Symptoms**:
```
PG::ConnectionBad: could not connect to server: Connection refused
```

**Solution**:
```bash
# Check if PostgreSQL is running:
brew services list | grep postgresql  # macOS
sudo systemctl status postgresql      # Linux

# Start PostgreSQL:
brew services start postgresql@15     # macOS
sudo systemctl start postgresql       # Linux

# Verify port is correct in .env:
WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_master_dev
```

### Issue 3: Migration Fails with "PG::UndefinedTable"

**Symptoms**:
```
PG::UndefinedTable: ERROR:  relation "schema_info" does not exist
```

**Solution**:
```bash
# Database was not created properly. Drop and recreate:
dropdb -h 127.0.0.1 -U postgres webpay_master_dev
createdb -h 127.0.0.1 -U postgres webpay_master_dev

# Run migrations again:
WP_ENV=development bundle exec rake db:migrate
```

### Issue 4: Puma Won't Start - Address Already in Use

**Symptoms**:
```
Address already in use - bind(2) for "0.0.0.0" port 4444
```

**Solution**:
```bash
# Find process using port 4444:
lsof -i :4444

# Kill the process:
kill -9 <PID>

# Or use killall:
killall -9 puma

# Start Puma again:
WP_ENV=development RUBYOPT="-W0" puma -v -t 2:2 -b tcp://0.0.0.0:4444
```

### Issue 5: CORS Errors in Frontend

**Symptoms**:
```
Access to XMLHttpRequest at 'http://localhost:4444/api/login' from origin 'http://localhost:2222' has been blocked by CORS policy
```

**Solution**:
```bash
# Check config.ru for CORS configuration:
# Ensure WP_SPA_HOST_URL is correct in .env:
WP_SPA_HOST_URL='http://localhost:2222/#!'

# Enable CORS in config.ru:
require 'rack/cors'
use Rack::Cors do
  allow do
    origins '*'  # or specific origin for production
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
  end
end

# Restart Puma
```

### Issue 6: Emails Not Sending (Local Development)

**Symptoms**:
```
Connection refused - connect(2) for "localhost" port 1025
```

**Solution**:
```bash
# Install and run mailcatcher:
gem install mailcatcher
mailcatcher

# Access mailcatcher UI:
open http://localhost:1080

# Verify SMTP settings in .env:
WP_SMTP_HOST=localhost
WP_SMTP_PORT=1025
```

### Issue 7: Ruby Version Mismatch

**Symptoms**:
```
Your Ruby version is 3.2.0, but your Gemfile specified 3.3.0
```

**Solution**:
```bash
# Install correct Ruby version:
rbenv install 3.3.0
rbenv local 3.3.0  # or rbenv global 3.3.0

# Verify:
ruby -v
# Should output: ruby 3.3.0
```

---

## Testing Checklist

### After Fresh Installation

- [ ] Backend starts successfully on port 4444
- [ ] Frontend starts successfully on port 2222
- [ ] Database has 135 migrations applied
- [ ] Login page loads without errors
- [ ] API health check returns 200 OK (if endpoint exists)
- [ ] Mailcatcher captures test emails
- [ ] No errors in browser console (except expected warnings)

### After UAT Migration

- [ ] Database backup created and verified
- [ ] Old service stopped gracefully
- [ ] Git pull completed without conflicts
- [ ] `bundle install` completed successfully
- [ ] All database migrations executed successfully
- [ ] New schema version is 135 (or latest)
- [ ] Service restarted successfully
- [ ] Login functionality works
- [ ] OTP activation works (if applicable)
- [ ] Account transactions work
- [ ] No errors in production logs

### Smoke Test Scenarios

1. **User Registration & OTP Activation**
   - Register new user
   - Receive OTP email
   - Activate with OTP code
   - Login successfully

2. **Account Management**
   - View account list
   - View account details
   - Check balance

3. **Transactions**
   - View transaction history
   - Create test transaction
   - Verify transaction appears in list

4. **Admin Functions** (if applicable)
   - Admin login
   - View user list
   - Manage settings

---

## Rollback Procedure (UAT/Production)

If deployment fails and you need to rollback:

### 1. Stop Service

```bash
sudo systemctl stop webpay-master
```

### 2. Rollback Code

```bash
cd /var/www/webpay-master
git log -10 --oneline  # Find previous commit
git reset --hard <previous-commit-hash>
```

### 3. Rollback Database

```bash
# Drop current database:
dropdb -h localhost -U postgres -p 5433 webpay_production_2022

# Restore from backup:
createdb -h localhost -U postgres -p 5433 webpay_production_2022
pg_restore -h localhost -U postgres -p 5433 -d webpay_production_2022 /backup/webpay_uat_backup_20251102_143000.tar
```

### 4. Rollback Dependencies (if needed)

```bash
# If Gemfile.lock changed:
git checkout <previous-commit> -- Gemfile.lock
bundle install
```

### 5. Restart Service

```bash
sudo systemctl start webpay-master
sudo systemctl status webpay-master
```

### 6. Verify Rollback

```bash
# Check schema version:
psql -h localhost -U postgres -p 5433 webpay_production_2022 -c "SELECT version FROM schema_info;"

# Test login and key functionality
```

---

## Additional Resources

- **UAT Database Import**: See `UAT_DATABASE_IMPORT.md` for importing real UAT data locally
- **Security Fixes**: See `SECURITY_FIXES.md` for recent security patches
- **OTP Activation Flow**: See `OTP_ACTIVATION_FLOW.md` for detailed OTP implementation
- **Testing Results**: See `TESTING_RESULTS.md` for comprehensive test coverage
- **WebPay Context**: See `WEBPAY_MASTER_CONTEXT.md` for architecture overview

---

## Support

If you encounter issues not covered in this guide:

1. **Check logs**:
   ```bash
   tail -f /var/log/webpay-master/puma.log
   tail -f /var/log/postgresql/postgresql-15-main.log
   ```

2. **Check GitHub Issues**: https://github.com/WebtehInc/webpay-master-2/issues

3. **Contact team**:
   - Email: dev-team@webteh.us
   - Slack: #webpay-dev

---

**Document Version**: 2.0
**Last Updated**: 2025-11-02
**Maintainer**: WebPay Development Team
**Generated with**: Claude Code
