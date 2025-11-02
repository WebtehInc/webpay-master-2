# UAT Database Import - Dokumentacija

## ⚡ GOTOVA UAT BAZA - ODMAH DOSTUPNA

**UAT baza je već importovana i spremna za korištenje!**

```
Database: webpay_development_uat
User:     webpay_user
Password: webpay123
Schema:   Version 135 (up-to-date)
Data:     10 users, 13 accounts, 5,241 transactions
```

**Kako koristiti UAT bazu:**

1. Promijeni `.env` fajl:
   ```bash
   # Umjesto:
   WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/webpay_master_dev

   # Koristi:
   WP_DEV_DATABASE_URL=postgres://webpay_user:webpay123@127.0.0.1:5435/webpay_development_uat
   ```

2. Restartuj backend:
   ```bash
   # Stopuj trenutni backend (Ctrl+C)
   # Pokreni ponovo:
   cd /Users/igor/ClaudeAI/webpay-master/v2-current
   eval "$(rbenv init - zsh)"
   WP_ENV=development RUBYOPT="-W0" puma -v -t 2:2 -b tcp://0.0.0.0:4444
   ```

Sada aplikacija koristi UAT bazu sa pravim test podacima!

---

## Pregled

Ovaj dokument objašnjava kako importovati UAT AWS bazu u lokalnu PostgreSQL instancu i usporediti schema sa trenutnom dev bazom.

## Scenario

UAT AWS okruženje ima production bazu sa **~10 klijenata i transakcijama** koja se koristi za testiranje. Želimo ovu bazu importovati lokalno kako bismo:

1. Imali realne test podatke umjesto prazne baze
2. Testirali funkcionalnost sa pravim podacima
3. Provjerili performance sa realističnim volumenom podataka

## Preduvjeti

1. PostgreSQL 15.14 pokrenut na portu 5435
2. Dump file UAT baze (`.sql` ili `.sql.gz`)
3. Pristup UAT AWS bazi za kreiranje dumpa (ako već nije kreiran)

## Koraci

### 1. Kreiranje UAT Dumpa (na UAT serveru ili lokalno sa pristupom)

**UAT Environment Info:**
- Database: PostgreSQL 13.20 (Aurora)
- Host: `aurora-pg1`
- Port: `5433`
- Database Name: `webpay_production_2022`
- Local Target: PostgreSQL 15.14 (Homebrew)

**Komanda za Dump (Tar Format - Preporučeno):**

```bash
# Na UAT serveru ili sa pristupom UAT AWS bazi:
pg_dump -h aurora-pg1 \
        -U postgres \
        -p 5433 \
        -W \
        -F t \
        webpay_production_2022 > webpay_production_2022.tar

# -F t = tar format (najbolji za pg_restore)
# -W = Prompt za password
```

**PostgreSQL Version Compatibility:**
- ✅ PostgreSQL 13.20 → 15.14 je forward-compatible
- ✅ Dump sa starije verzije radi na novijoj verziji
- ✅ Tar format (`-F t`) omogućava selektivni import tabela
- ⚠️ Reverse (15.14 → 13.20) ne bi radilo

**Alternative Format Options:**

```bash
# Custom format (compressed, flexible):
pg_dump -h aurora-pg1 -U postgres -p 5433 -W -F c webpay_production_2022 > webpay_production_2022.dump

# Plain SQL (human-readable):
pg_dump -h aurora-pg1 -U postgres -p 5433 -W webpay_production_2022 > webpay_production_2022.sql

# Gzipped SQL:
pg_dump -h aurora-pg1 -U postgres -p 5433 -W webpay_production_2022 | gzip > webpay_production_2022.sql.gz
```

**Transfer Dumpa na Lokalni Računar:**

```bash
# Ako je dump kreiran na remote serveru:
scp user@uat-server:/path/webpay_production_2022.tar ~/Downloads/

# Ili direktno sa lokalne mašine ako imaš pristup:
pg_dump -h aurora-pg1 -U postgres -p 5433 -W -F t webpay_production_2022 > ~/Downloads/webpay_production_2022.tar
```

### 2. Import UAT Baze Automatski (Preporučeno)

Koristite automatsku skriptu koja će:
- Kreirati novu bazu `webpay_master_uat`
- Importovati dump
- Uporediti schema verzije
- Pokazati razlike u tabelama i kolonama
- Preporučiti potrebne migracije

```bash
cd /Users/igor/ClaudeAI/webpay-master/v2-current

# Pokreni import script (tar format):
./import_uat_database.sh ~/Downloads/webpay_production_2022.tar

# Ili plain SQL:
./import_uat_database.sh ~/Downloads/webpay_uat_dump.sql

# Ili compressed:
./import_uat_database.sh ~/Downloads/webpay_uat_dump.sql.gz
```

**Script će automatski detektovati format:**
- `.tar` → koristi `pg_restore`
- `.dump` ili `.custom` → koristi `pg_restore`
- `.sql.gz` → koristi `gunzip | psql`
- `.sql` → koristi `psql`

Script će kreirati:
- `webpay_master_uat` bazu
- `dev_schema.txt` - DEV schema info
- `uat_schema.txt` - UAT schema info
- `schema_diff.txt` - Razlike između schemi (samo ako postoje)

### 3. Import UAT Baze Manualno

Ako želiš manualni import:

```bash
# 1. Kreiraj bazu
createdb -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat

# 2a. Importuj tar format dump (pg_restore):
pg_restore -h 127.0.0.1 -p 5435 -U postgres -d webpay_master_uat -v ~/Downloads/webpay_production_2022.tar

# 2b. Ili plain SQL dump:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat < ~/Downloads/webpay_uat_dump.sql

# 2c. Ili compressed SQL:
gunzip -c ~/Downloads/webpay_uat_dump.sql.gz | psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat

# 3. Provjeri schema version
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat -c "SELECT version FROM schema_info;"
```

**pg_restore Napredne Opcije:**

```bash
# Selective restore - samo određene tabele:
pg_restore -h 127.0.0.1 -p 5435 -U postgres -d webpay_master_uat \
  -t users -t accounts -t transactions \
  ~/Downloads/webpay_production_2022.tar

# Parallel restore (brže za velike baze):
pg_restore -h 127.0.0.1 -p 5435 -U postgres -d webpay_master_uat \
  -j 4 \
  ~/Downloads/webpay_production_2022.tar

# Lista dostupnih objekata u dump file-u:
pg_restore -l ~/Downloads/webpay_production_2022.tar
```

### 4. Uporedi Scheme

#### Opcija A: SQL Script sa dblink

```bash
# Prvo instaliraj dblink extension u DEV bazi:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_dev -c "CREATE EXTENSION IF NOT EXISTS dblink;"

# Pokreni comparison script:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_dev -f compare_schemas.sql
```

#### Opcija B: SQL Script bez dblink (jednostavniji)

```bash
# Generiši schema info za DEV:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_dev -f compare_schemas_simple.sql > dev_schema_output.txt

# Generiši schema info za UAT:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat -f compare_schemas_simple.sql > uat_schema_output.txt

# Uporedi sa diff:
diff -u dev_schema_output.txt uat_schema_output.txt
```

### 5. Primjena Migracija na UAT Bazu (Ako je Potrebno)

Ako UAT baza ima stariju schema verziju (npr. version 133, a DEV ima 135):

```bash
# Pokreni migracije na UAT bazi:
cd /Users/igor/ClaudeAI/webpay-master/v2-current

WP_ENV=development \
WP_DATABASE_NAME=webpay_master_uat \
WP_DEV_DATABASE_URL='postgres://postgres:postgres@127.0.0.1:5435/webpay_master_uat' \
bundle exec rake db:migrate

# Provjeri novu verziju:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat -c "SELECT version FROM schema_info;"
```

### 6. Korištenje UAT Baze za Testiranje

#### Privremeno Prebacivanje na UAT Bazu

Ažuriraj `.env` file:

```bash
# Umjesto:
WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/webpay_master_dev

# Koristi:
WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/webpay_master_uat
```

Restartuj backend:

```bash
cd /Users/igor/ClaudeAI/webpay-master/v2-current
eval "$(rbenv init - zsh)"
WP_ENV=development RUBYOPT="-W0" puma -v -t 2:2 -b tcp://0.0.0.0:4444
```

#### Vraćanje na DEV Bazu

```bash
# Vrati .env na original:
WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/webpay_master_dev

# Restartuj backend
```

## Očekivani Rezultati

Nakon uspješnog importa, imaćeš:

- ✅ `webpay_master_uat` bazu sa ~10 klijenata
- ✅ Realne transakcije i račune za testiranje
- ✅ Mogućnost testiranja svih funkcionalnosti sa pravim podacima
- ✅ Uporedbu schema između DEV i UAT verzija
- ✅ Lista potrebnih migracija (ako postoje razlike)

## Provjera Row Counts

```bash
# Provjeri broj redova u svakoj tabeli:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat <<EOF
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
EOF
```

Očekujem vidjeti:
- `users` tabla sa ~10-15 korisnika
- `accounts` tabla sa multiple računa
- `transactions` tabla sa istorijskim transakcijama
- `settings` tabla sa UAT konfiguracijama

## Comparison Output Primjeri

### Ako su Scheme Iste:

```
[SUCCESS] Schemas are identical!
[SUCCESS] UAT database is up-to-date! No migrations needed.
```

### Ako su Scheme Različite:

```
[WARNING] Schema versions differ! Migration needed.
  DEV schema version: 135
  UAT schema version: 133

  To migrate UAT database, run these migrations:
    Migration 134: 134_add_otp_fields_to_users.rb
    Migration 135: 135_add_jwt_fields_to_settings.rb

  Run migrations with:
    WP_ENV=development WP_DATABASE_NAME=webpay_master_uat bundle exec rake db:migrate
```

## Troubleshooting

### Error: Database Already Exists

```bash
# Obriši postojeću UAT bazu:
dropdb -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat

# Pa ponovo pokreni import script
./import_uat_database.sh ~/Downloads/webpay_uat_dump.sql
```

### Error: Permission Denied

```bash
# Provjeri PostgreSQL pristup:
psql -h 127.0.0.1 -p 5435 -U postgres -l

# Ako ne radi, provjeri da li je PostgreSQL pokrenut:
brew services list | grep postgresql
```

### Error: Migration Failed

```bash
# Provjeri detalje greške:
WP_ENV=development \
WP_DEV_DATABASE_URL='postgres://postgres:postgres@127.0.0.1:5435/webpay_master_uat' \
bundle exec rake db:migrate --trace

# Ako je problem sa specific migracijom, može se skinut:
psql -h 127.0.0.1 -p 5435 -U postgres webpay_master_uat <<EOF
UPDATE schema_info SET version = 134;  -- Skip problematic migration
EOF
```

## Best Practices

1. **Backup Before Import**: Ako već imaš UAT bazu lokalno, napravi backup prije novog importa
2. **Schema Comparison**: Uvijek uporedi scheme prije nego počneš koristiti UAT bazu
3. **Run Migrations**: Ako UAT baza ima stariju verziju, pokreni migracije prije testiranja
4. **Separate Databases**: Drži DEV i UAT baze odvojene - ne mixuj podatke
5. **Regular Updates**: Periodički ažuriraj UAT dump sa najnovijim production podacima

## Files Kreirane Tokom Importa

```
/Users/igor/ClaudeAI/webpay-master/v2-current/
├── import_uat_database.sh      # Glavni import script
├── compare_schemas.sql          # Schema comparison sa dblink
├── compare_schemas_simple.sql   # Schema comparison bez dblink
├── dev_schema.txt              # DEV schema output (generated)
├── uat_schema.txt              # UAT schema output (generated)
└── schema_diff.txt             # Razlike između schemi (generated if different)
```

## Dodatna Podrška

Ako naiđeš na probleme:
1. Provjeri PostgreSQL log: `tail -f /usr/local/var/log/postgres.log`
2. Provjeri da li je port 5435 slobodan: `lsof -i :5435`
3. Provjeri disk space: `df -h`

---

## Quick Reference - Dostupna UAT Baza

**Lokalna UAT Baza (Već Importovana i Spremna):**
```
Host:     127.0.0.1
Port:     5435
Database: webpay_development_uat
User:     webpay_user
Password: webpay123
Version:  PostgreSQL 15.14 (Homebrew)
Schema:   Version 135 (up-to-date)

Data:
  - 10 users
  - 13 accounts
  - 13 admins
  - 91 customers
  - 23 operators
  - 27 terminals
  - 5,241 transactions
```

**AWS UAT Baza Info (Za Novi Dump):**
```
Host:     aurora-pg1
Port:     5433
Database: webpay_production_2022
Version:  PostgreSQL 13.20 (Aurora)
```

**Brzi Setup (3 Komande):**

```bash
# 1. Dump UAT baze (sa pristupom):
pg_dump -h aurora-pg1 -U postgres -p 5433 -W -F t webpay_production_2022 > ~/Downloads/webpay_production_2022.tar

# 2. Import u lokalnu bazu (automatski):
cd /Users/igor/ClaudeAI/webpay-master/v2-current
./import_uat_database.sh ~/Downloads/webpay_production_2022.tar

# 3. Primijeni migracije (ako je potrebno):
WP_ENV=development WP_DATABASE_NAME=webpay_master_uat bundle exec rake db:migrate
```

**Prebacivanje na UAT Bazu:**

```bash
# Ažuriraj .env:
# WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5435/webpay_master_uat

# Restartuj backend:
cd /Users/igor/ClaudeAI/webpay-master/v2-current
eval "$(rbenv init - zsh)"
WP_ENV=development RUBYOPT="-W0" puma -v -t 2:2 -b tcp://0.0.0.0:4444
```

**PostgreSQL Version Notes:**
- ✅ 13.20 → 15.14 je potpuno kompatibilno
- ✅ Sve funkcionalnosti rade
- ✅ Performance improvements uključeni
- ⚠️ Ako vidiš warnings tokom importa, to je normalno (deprecated features)

---

**Napomena**: Ova baza **nema osjetljivih podataka** - to su Webteh test podaci sa UAT okruženja.

**Kreirao**: Claude Code - 2025-11-01
**Verzija**: 1.1 (Updated for PostgreSQL 13.20 → 15.14 + tar format)
**Last Updated**: 2025-11-01 22:40
