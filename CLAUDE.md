# CLAUDE.md - AI Assistant Guide for WebPay Master

**Version:** 1.0
**Last Updated:** 2025-11-15
**Project:** WebPay Master - Online Banking with mPOS Backend

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Codebase Structure](#codebase-structure)
3. [Technology Stack](#technology-stack)
4. [Development Workflows](#development-workflows)
5. [Testing Guidelines](#testing-guidelines)
6. [Key Conventions & Patterns](#key-conventions--patterns)
7. [Security Considerations](#security-considerations)
8. [Common Tasks & Operations](#common-tasks--operations)
9. [Troubleshooting & Tips](#troubleshooting--tips)
10. [Known Technical Debt](#known-technical-debt)

---

## Project Overview

### What is WebPay Master?

WebPay Master is a **Ruby-based online banking and mobile point-of-sale (mPOS) backend system** that handles:

- Digital wallet operations (accounts, transactions, transfers)
- Payment card processing (authorization, sale, refund, void)
- POS terminal management and cashier operations
- Bill payments and prepaid services (utilities, vouchers)
- Integration with payment gateways and core banking systems
- Secure authentication with JWT and TOTP 2FA

### Architecture Type

- **Framework:** Roda (routing tree web framework, similar to Sinatra)
- **Pattern:** Service-oriented architecture with DStruct service objects
- **API Type:** JSON REST API (public endpoints + JWT-protected private endpoints)
- **Frontend:** Separate Vue.js SPA (webpay-spa repository)
- **Deployment:** Dockerized, Puma web server, PostgreSQL database

### Current State

- **Ruby Version:** 2.6.8 (EOL - upgrade to 3.3 planned)
- **Production Status:** Active production system
- **Maintenance Mode:** Security updates and bug fixes (Phase 1 in progress)

---

## Codebase Structure

### Directory Layout

```
webpay-master-2/
│
├── config.ru                   # Rack entry point (CORS, static assets, app loader)
├── webpay.rb                   # Main Roda app (routing, auth, error handling)
├── models.rb                   # Model loader & constants
├── Gemfile                     # Ruby dependencies
├── Rakefile                    # Test tasks & custom rake tasks
│
├── routes/                     # Roda route modules
│   ├── private/               # JWT-protected routes
│   │   ├── accounts.rb        # Account management
│   │   ├── transactions.rb    # Transaction history
│   │   ├── terminals.rb       # Terminal operations
│   │   ├── cards.rb           # Card management
│   │   ├── customers.rb       # Customer data
│   │   └── ...
│   └── (public routes in webpay.rb)
│
├── models/                     # Sequel ORM models + business logic
│   ├── user/                  # User authentication & operations
│   │   ├── login.rb           # Login service
│   │   ├── signup.rb          # Registration service
│   │   └── ...
│   ├── account/               # Account models & services
│   ├── transaction/           # Transaction processing
│   ├── terminal/              # POS terminal management
│   ├── card/                  # Card management
│   ├── api/                   # MPOS API handlers (DStruct)
│   │   ├── topup.rb           # Top-up operation
│   │   ├── bill_payment.rb    # Bill payment
│   │   ├── sale.rb            # Card sale
│   │   └── ...
│   └── ...
│
├── services/                   # External service integrations
│   ├── card_authorization_service.rb  # Card processing
│   ├── core_bank_service.rb   # Core banking integration
│   ├── fiserv_service.rb      # Fiserv API
│   ├── pagatinu_service.rb    # Prepaid services (3 versions!)
│   ├── curgas_service.rb      # Gas utility payments
│   └── tax_service.rb         # Tax payments
│
├── gateways/                   # Payment gateway integrations
│   ├── infoswitch/            # ISO 8583 payment switch
│   ├── jsecmodule/            # Crypto operations
│   └── dummy.rb               # Mock gateway for dev/test
│
├── lib/                        # Shared libraries
│   ├── pagatinu_client.rb     # HTTP client for Pagatinu
│   ├── fiserv_client.rb       # HTTP client for Fiserv
│   └── tasks/                 # Rake tasks
│
├── db/                         # Database files
│   ├── migrations/            # 100+ Sequel migrations
│   └── database.rb            # DB config & helpers
│
├── test/                       # Minitest test suite
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   │   ├── user_transactions/ # Wallet tests
│   │   ├── pos_api/           # MPOS API tests
│   │   └── infoswitch/        # Gateway tests
│   └── helpers/               # Test helpers & fixtures
│
├── plugins/                    # Roda plugins
│   └── jwt.rb                 # JWT authentication
│
├── env/                        # Environment configurations
│   ├── environment.rb         # Environment loader
│   ├── development.rb
│   ├── test.rb
│   └── production.rb
│
├── views/                      # View templates (minimal - mostly JSON)
├── public/                     # Static assets
├── demo/                       # Demo scripts
└── docs/                       # Documentation

```

### Key Entry Points

| File | Purpose | Key Responsibilities |
|------|---------|---------------------|
| **config.ru** | Rack configuration | CORS, secure headers, static assets, app bootstrap |
| **webpay.rb** | Main application | Routing tree, authentication, error handling, public API |
| **models.rb** | Model loader | Load all models, define constants (transaction types, currencies) |
| **env/environment.rb** | Environment config | Database connection, Redis, environment-specific settings |
| **Rakefile** | Task runner | Test tasks (`rake test`, `rake unit`, `rake integration`) |

### Important Files to Review

- **WEBPAY_MASTER_CONTEXT.md** - Current project status and Phase 1 plan
- **CONTRIBUTING.md** - Development environment setup
- **README.md** - Quick start guide
- **.env.example.txt** - Environment variable template
- **routes.txt** - Generated route list

---

## Technology Stack

### Core Technologies

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Language** | Ruby | 2.6.8 | Main programming language |
| **Framework** | Roda | 3.x | Routing tree web framework |
| **Web Server** | Puma | 5.6 | Multi-threaded web server |
| **Database** | PostgreSQL | Latest | Relational database |
| **ORM** | Sequel | Latest | Database toolkit |
| **Cache** | Memcached | Latest | Session & OTP storage |

### Key Dependencies

#### Web & HTTP
```ruby
gem "rack", "~> 2.2", ">= 2.2.6"     # Web server interface
gem "rack-cors", "~> 1.1"            # CORS middleware
gem "roda"                           # Routing framework
gem "roda-symbolized_params"         # Symbol params plugin
gem "faraday", "1.10.3"              # HTTP client
gem "useragent"                      # User agent parsing
```

#### Authentication & Security
```ruby
gem "jwt"                            # JSON Web Tokens
gem "bcrypt"                         # Password hashing
gem "rotp", "3.3.1"                  # TOTP 2FA (outdated!)
gem "rqrcode"                        # QR codes for 2FA
```

#### Validation & Data Structures
```ruby
gem "dry-validation", "0.7.4"        # Input validation (ANCIENT!)
gem "dry-types", "0.7.1"             # Type system
gem "dry-logic", "0.2.2"             # Validation logic
gem "d_struct"                       # Data structures with validation
```

#### Database & Caching
```ruby
gem "sequel"                         # ORM
gem "sequel_pg", require: "sequel"   # PostgreSQL adapter
gem "pg"                             # PostgreSQL driver
gem "philtre"                        # Query filtering
gem "dalli"                          # Memcached client
```

#### Utilities
```ruby
gem "oj"                             # Fast JSON parser
gem "nokogiri", "1.13.10"            # XML/HTML parsing (vulnerable!)
gem "builder"                        # XML builder
gem "mail"                           # Email sending
gem "ibanizator"                     # IBAN generation
gem "activesupport", "~> 6.1"        # Rails utilities
```

#### Development & Testing
```ruby
gem "minitest"                       # Test framework
gem "webmock"                        # HTTP request stubbing
gem "vcr"                            # HTTP interaction recording
gem "rack-test"                      # Rack app testing
gem "faker"                          # Test data generation
gem "pry"                            # REPL debugger
gem "awesome_print"                  # Pretty printing
gem "dotenv"                         # Environment variables
```

---

## Development Workflows

### Environment Setup

#### Prerequisites
- Ruby 2.6.8 (use rbenv or rvm)
- PostgreSQL 12+
- Memcached
- Docker (optional but recommended)

#### Setup Steps

**Option 1: Docker (Recommended)**
```bash
# Start development environment
docker-compose up

# In another terminal, enter container
docker-compose exec development bash -l

# Inside container
bundle install
rake db:migrate
```

**Option 2: Classic Setup**
```bash
# Install Ruby 2.6.8
rbenv install 2.6.8
rbenv local 2.6.8

# Install dependencies
bundle install

# Configure environment
cp .env.example.txt .env
# Edit .env with your settings:
#   WP_ENV=development
#   WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_dev

# Create database
createdb webpay_dev

# Run migrations
rake db:migrate

# Add hosts entry (for CORS)
echo "127.0.0.1 webpay" | sudo tee -a /etc/hosts

# Install webpay-spa for frontend
# (separate repository)
```

### Running the Application

```bash
# Development server with auto-reload
RUBYOPT="-W0" rerun -- puma -v -t 2:2 -b tcp://webpay:4444

# Or with puma config
RUBYOPT="-W0" rerun -- puma -C puma.rb -b tcp://webpay:4444

# Production mode
bundle exec puma -C puma.rb
```

**Environment Variables Required:**
- `WP_ENV` - Environment (development, test, production)
- `WP_DEV_DATABASE_URL` - Database connection string
- `WP_SPA_HOST_URL` - Frontend URL (for CORS)
- `WP_REDIS_URL` - Redis URL (optional)
- `WP_MEMCACHE_SERVERS` - Memcached servers

### Console Access

```bash
# Interactive Ruby console with app loaded
ruby console.rb
# or
ruby webpay_environment.rb

# Then you can interact with models:
# User.first
# Account.where(user_id: 1).all
# Transaction.recent(limit: 10)
```

### Database Operations

```bash
# Run all migrations
rake db:migrate

# Rollback one migration
rake db:rollback

# Reset database (drop, create, migrate)
rake db:reset

# Seed database (if seed file exists)
rake db:seed

# Create new migration
rake db:create_migration NAME=add_field_to_table
```

---

## Testing Guidelines

### Test Structure

The project uses **Minitest** with comprehensive unit and integration tests.

```
test/
├── test_helper.rb              # Test configuration & helpers
├── unit/                       # Fast isolated tests
│   ├── test_login.rb
│   ├── test_signup.rb
│   └── unit_helper.rb
├── integration/                # Full request/response tests
│   ├── user_transactions/     # Wallet operations
│   ├── pos_api/               # MPOS API endpoints
│   └── infoswitch/            # Payment gateway
└── helpers/
    ├── stub_any_instance.rb   # Stubbing helper
    └── luhnacy.rb             # Credit card generation
```

### Running Tests

```bash
# Set test environment
export WP_ENV=test
export WP_TEST_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_test

# Run all tests
RUBYOPT=-W0 rake test

# Run only unit tests
RUBYOPT=-W0 rake unit

# Run only integration tests
RUBYOPT=-W0 rake integration

# Run specific test file
RUBYOPT=-W0 ruby -Itest test/unit/test_login.rb

# Run specific test method
RUBYOPT=-W0 ruby -Itest test/unit/test_login.rb -n test_login_success

# Docker testing
docker-compose -f docker-compose-test.yml up --exit-code-from test
```

### Test Conventions

**Test Helper Setup:**
```ruby
class Minitest::Test
  def setup
    # Database is wiped clean before each test
    [:users, :accounts, :transactions, ...].each { |table| DB[table].delete }

    # VCR cassette for HTTP mocking
    VCR.insert_cassette(@__vcr_cassette_name)
  end

  def teardown
    VCR.eject_cassette
  end
end
```

**Factory Methods:**
```ruby
# Use helper methods to generate test data
def generate_user(attrs = {})
  User.create({
    email: 'test@example.com',
    password: 'password123',
    first_name: 'Test',
    last_name: 'User'
  }.merge(attrs))
end

def generate_terminal(attrs = {})
  Terminal.create({
    access_token: SecureRandom.hex(32),
    name: 'Test Terminal'
  }.merge(attrs))
end
```

**Request Testing:**
```ruby
# Use rack-test helpers
post '/login', {email: 'test@example.com', password: 'password123'}.to_json

assert last_response.ok?
assert_equal 200, last_response.status

data = JSON.parse(last_response.body)
assert data['token']
```

**VCR for External APIs:**
```ruby
# VCR automatically records HTTP interactions
VCR.use_cassette('fiserv_topup') do
  response = FiservService.topup(terminal, params)
  assert response[:success]
end
```

### Writing Tests

**Dos:**
- ✅ Clean database before each test
- ✅ Use VCR for external API calls
- ✅ Test both success and failure cases
- ✅ Test validation errors
- ✅ Test authentication/authorization
- ✅ Use factory methods for test data
- ✅ Name tests descriptively (`test_login_with_invalid_password`)

**Don'ts:**
- ❌ Share state between tests
- ❌ Make real external API calls (use VCR)
- ❌ Skip database cleanup
- ❌ Test implementation details
- ❌ Use production credentials in tests

---

## Key Conventions & Patterns

### Routing Pattern (Roda Multi-Route Plugin)

Routes are organized in separate files under `routes/private/`:

```ruby
# routes/private/accounts.rb
WebPay.route('accounts') do |r|
  # GET /accounts/:id
  r.on ':id' do |id|
    @account = Account[id]

    # Nested routes
    r.is do
      r.get do
        render_success(@account.public_values)
      end

      r.post 'update' do
        authorize!  # Requires 2FA
        UpdateAccount.call(account_id, self)
      end
    end
  end
end
```

**Loading routes in webpay.rb:**
```ruby
route('accounts', 'private/accounts')
route('transactions', 'private/transactions')
route('terminals', 'private/terminals')
```

### Service Object Pattern (DStruct)

Business logic is encapsulated in service objects using **DStruct**:

```ruby
# models/api/topup.rb
class TopUp < DStruct::DStruct
  # Define typed attributes
  attributes strings: [:access_token, :digest, :systan],
             integers: [:amount, :cashier_id],
             times: [:client_datetime]

  # Main entry point
  def self.call(context)
    # 1. Parse input
    input = new(context.params)

    # 2. Fetch dependencies
    terminal = Terminal.where(access_token: input.access_token).first
    account = terminal.account

    # 3. Define validation
    validation_schema = Dry::Validation.Form do
      configure do
        config.messages_file = 'config/errors.yml'
        predicates(CustomPredicates)
      end

      key(:amount) { int? & over_min_amount? & below_max_amount? }
      key(:access_token) { filled? & valid_terminal? }
    end

    input.add_validation_schema validation_schema

    # 4. Validate & process
    if input.valid?
      DB.transaction do
        # Create transactions
        # Update balances
      end
      context.render_success(response_data)
    else
      context.render_error(input.errors)
    end
  end
end
```

**Key characteristics:**
- Type-safe input with DStruct
- Declarative validation with dry-validation
- Single `.call(context)` class method
- Database transactions for consistency
- Returns JSON via context render methods

### Model Conventions (Sequel)

Models inherit from `Sequel::Model` with consistent patterns:

```ruby
# models/user.rb
class User < Sequel::Model
  # Plugins
  plugin :dirty                # Track changes
  plugin :serialization        # JSON columns
  plugin :validation_helpers

  # Associations
  one_to_many :audits
  many_to_many :accounts, join_table: :accounts_users

  # Hooks
  def before_create
    self.created_at = Time.now
  end

  # Public vs private attributes
  PUBLIC_ATTRS = [:id, :email, :first_name, :last_name, :phone]
  NON_PUBLIC_ATTRS = [:password_hash, :otp_code, :otp_secret]

  def public_values
    values.slice(*PUBLIC_ATTRS)
  end

  # Class methods for operations
  def self.update_with_audit(id, attrs={}, user_id = nil)
    instance = self[id]
    if instance.update(attrs)
      instance.audit(user_id, [])
    end
  end

  # Instance methods
  def audit(user_id, non_audited_attrs)
    add_audit(
      model_name: self.class.name,
      user_id: user_id,
      diff: previous_changes.reject { |k, v| non_audited_attrs.include?(k) }
    )
  end
end
```

**Model structure:**
- Separate files for business operations (`user/login.rb`, `user/signup.rb`)
- Public vs. non-public attributes
- Audit trail on all changes
- Pessimistic locking in transactions (`account.lock!`)

### Authentication & Authorization

**JWT Authentication:**
```ruby
# Middleware in webpay.rb
def authenticate!
  if env['HTTP_AUTHORIZATION']
    encoded_token = env['HTTP_AUTHORIZATION'].split(' ').last
    if decoded_token = Jwt.decode_token(self, encoded_token)
      self.user_id = decoded_token[0]['user_id']
      return
    end
  end
  render_unauthorized(['token is missing or invalid'])
end
```

**2FA Authorization:**
```ruby
# For sensitive operations
def authorize!
  otp = request.params['otp']

  # Mobile app bypass with digest
  if digest_valid?(request)
    return
  end

  # Check OTP
  unless valid_otp?(user_id, otp)
    render_forbidden({ otp: 'pending' })
  end
end
```

### Response Patterns

**Success Response:**
```ruby
def render_success(data, token = nil)
  response.status = 200
  response['Content-Type'] = 'application/json'
  response.write({ data: data, token: token }.to_json)
end
```

**Error Response (Validation):**
```ruby
def render_error(errors)
  response.status = 422
  response['Content-Type'] = 'application/json'
  response.write(errors.to_json)
end

# Example output:
# { "email": ["is required"], "amount": ["must be greater than 100"] }
```

**Unauthorized:**
```ruby
def render_unauthorized(errors = [])
  response.status = 401
  response['Content-Type'] = 'application/json'
  response.write(errors.to_json)
end

# Example output:
# ["token is missing or invalid"]
```

**Forbidden (OTP pending):**
```ruby
def render_forbidden(errors = {})
  response.status = 403
  response['Content-Type'] = 'application/json'
  response.write(errors.to_json)
end

# Example output:
# { "otp": "pending" }
```

### Transaction Pattern

**Critical financial operations use database transactions:**

```ruby
DB.transaction do
  # 1. Lock accounts (pessimistic locking)
  debit_account = Account[debit_account_id].lock!
  credit_account = Account[credit_account_id].lock!

  # 2. Validate balances
  raise InsufficientFunds if debit_account.balance < amount

  # 3. Create debit transaction
  debit_tx = Transaction.create(
    account_id: debit_account.id,
    amount: -amount,
    type: 'transfer_out'
  )

  # 4. Create credit transaction
  credit_tx = Transaction.create(
    account_id: credit_account.id,
    amount: amount,
    type: 'transfer_in'
  )

  # 5. Update balances
  debit_account.update(balance: debit_account.balance - amount)
  credit_account.update(balance: credit_account.balance + amount)

  # 6. Fee transaction created automatically via after_create hook
end
```

**Always:**
- ✅ Use `DB.transaction` for multi-step operations
- ✅ Lock records with `.lock!` to prevent race conditions
- ✅ Validate before modifying data
- ✅ Create audit trail
- ✅ Handle errors and rollback

### Validation Pattern

**Dry-validation schemas:**

```ruby
validation_schema = Dry::Validation.Form do
  configure do
    config.messages_file = 'config/errors.yml'

    # Custom predicates
    predicates(CustomPredicates)

    # Options for predicates
    option :terminal
    option :account
  end

  # Required fields
  key(:amount) { int? & gt?(0) }
  key(:email) { filled? & format?(EMAIL_REGEX) }

  # Optional fields
  optional(:phone) { format?(PHONE_REGEX) }

  # Custom predicates
  key(:access_token) { filled? & valid_terminal? }

  # Conditional validation
  rule(amount_within_limit: [:amount, :account_id]) do |amount, account_id|
    account_id.filled? > amount.lteq?(account.balance)
  end
end
```

**Custom predicates:**
```ruby
module CustomPredicates
  include Dry::Logic::Predicates

  predicate(:valid_terminal?) do |value|
    Terminal.where(access_token: value, active: true).count == 1
  end

  predicate(:over_min_amount?) do |value|
    value >= MIN_TRANSACTION_AMOUNT
  end
end
```

### Constants & Configuration

**Defined in models.rb:**

```ruby
# Transaction types
TRANSACTION_TYPES = {
  topup: 'topup',
  bill_payment: 'bill_payment',
  transfer: 'transfer',
  card_sale: 'card_sale',
  card_refund: 'card_refund',
  fee: 'fee',
  # ... more types
}

# Payment methods
PAYMENT_METHODS = {
  wallet: 'wallet',
  card: 'card',
  cash: 'cash'
}

# User types
USER_TYPES = {
  customer: 'customer',
  merchant: 'merchant',
  cashier: 'cashier',
  admin: 'admin'
}

# Currencies
CURRENCIES = {
  EUR: 'EUR',
  USD: 'USD'
}
```

---

## Security Considerations

### Critical Security Practices

**1. Password Security:**
```ruby
# Always use BCrypt for password hashing
require 'bcrypt'

# Hashing
def hash_password(password)
  BCrypt::Password.create(password)
end

# Verification
def verify_password(password, hash)
  BCrypt::Password.new(hash) == password
end
```

**2. Sensitive Data Masking:**
```ruby
# In logs and audit trails
def mask_sensitive_attrs
  masked = values.dup
  NON_PUBLIC_ATTRS.each { |attr| masked[attr] = '[FILTERED]' }
  masked
end
```

**3. JWT Token Security:**
```ruby
# Tokens expire after 24 hours
JWT.encode(
  { user_id: user.id, exp: Time.now.to_i + 86400 },
  ENV['JWT_SECRET'],
  'HS256'
)
```

**4. SQL Injection Prevention:**
```ruby
# ALWAYS use parameterized queries
# Good:
User.where(email: params[:email]).first

# Bad:
User.where("email = '#{params[:email]}'").first  # DON'T DO THIS!
```

**5. XSS Prevention:**
- API returns JSON only (no HTML rendering)
- Frontend (SPA) handles escaping
- Secure headers set in config.ru

**6. CSRF Protection:**
- JWT tokens provide CSRF protection
- No cookie-based sessions

**7. Rate Limiting:**
- Failed login attempts tracked
- Account lockout after threshold
- IP address logging

### Encryption & Crypto

**Payment Card Data:**
```ruby
# Card data encrypted via JsecModule gateway
encrypted_card = JsecModule.encrypt_card_data(
  pan: '4111111111111111',
  cvv: '123',
  expiry: '12/25'
)

# Store encrypted data only
card.update(encrypted_data: encrypted_card)
```

**Digest Verification:**
```ruby
# MPOS API uses SHA-512 digest for authentication
def digest_valid?(request)
  calculated = Utils.digest_SHA512(
    request.params.slice(:amount, :access_token, :systan).to_json
  )
  calculated == request.params[:digest]
end
```

### Audit Trail

**All data changes are audited:**

```ruby
# Automatic audit on model updates
def self.update(id, attrs={}, user_id = nil, non_audited_attrs = [])
  instance = self[id]
  if instance.update(attrs)
    instance.audit(user_id, non_audited_attrs)
  end
end

# Audit record structure
{
  model_name: 'User',
  user_id: 123,
  diff: {
    email: ['old@example.com', 'new@example.com'],
    phone: [nil, '+1234567890']
  },
  created_at: '2025-11-15 10:30:00'
}
```

### Environment Variables

**Never commit sensitive data:**
- ❌ Database passwords
- ❌ API keys
- ❌ JWT secrets
- ❌ Encryption keys

**Use .env files:**
```bash
# .env (gitignored)
WP_ENV=development
WP_DEV_DATABASE_URL=postgres://user:pass@localhost/webpay_dev
JWT_SECRET=your-secret-key-here
FISERV_API_KEY=api-key-here
```

---

## Common Tasks & Operations

### Adding a New Route

**1. Create route file:**
```ruby
# routes/private/my_resource.rb
WebPay.route('my_resource') do |r|
  r.on ':id' do |id|
    @resource = MyResource[id]

    r.is do
      r.get do
        render_success(@resource.public_values)
      end
    end
  end
end
```

**2. Load route in webpay.rb:**
```ruby
route('my_resource', 'private/my_resource')
```

**3. Write tests:**
```ruby
# test/integration/test_my_resource.rb
class TestMyResource < Minitest::Test
  def test_get_resource
    resource = generate_resource

    get "/my_resource/#{resource.id}", {}, auth_header

    assert last_response.ok?
    assert_equal resource.id, json_response['data']['id']
  end
end
```

### Adding a New Model

**1. Create migration:**
```bash
rake db:create_migration NAME=create_my_table
```

**2. Edit migration:**
```ruby
# db/migrations/XXX_create_my_table.rb
Sequel.migration do
  change do
    create_table :my_table do
      primary_key :id
      String :name, null: false
      Integer :user_id, null: false
      DateTime :created_at, null: false
      DateTime :updated_at

      index :user_id
    end
  end
end
```

**3. Create model:**
```ruby
# models/my_model.rb
class MyModel < Sequel::Model
  plugin :dirty
  plugin :validation_helpers

  many_to_one :user

  PUBLIC_ATTRS = [:id, :name, :created_at]

  def public_values
    values.slice(*PUBLIC_ATTRS)
  end

  def validate
    super
    validates_presence [:name, :user_id]
  end
end
```

**4. Load model in models.rb:**
```ruby
require_relative 'models/my_model'
```

### Adding a Service Object

**1. Create service:**
```ruby
# models/api/my_operation.rb
class MyOperation < DStruct::DStruct
  attributes strings: [:param1],
             integers: [:param2]

  def self.call(context)
    input = new(context.params)

    # Validation
    validation_schema = Dry::Validation.Form do
      key(:param1) { filled? }
      key(:param2) { int? & gt?(0) }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      # Business logic here
      result = perform_operation(input)
      context.render_success(result)
    else
      context.render_error(input.errors)
    end
  end

  private

  def self.perform_operation(input)
    # Implementation
  end
end
```

**2. Call from route:**
```ruby
r.post 'my_operation' do
  authenticate!
  MyOperation.call(self)
end
```

### Database Migrations

**Adding a column:**
```ruby
Sequel.migration do
  change do
    alter_table :users do
      add_column :new_field, String
    end
  end
end
```

**Adding an index:**
```ruby
Sequel.migration do
  change do
    alter_table :transactions do
      add_index :created_at
      add_index [:account_id, :type]
    end
  end
end
```

**Data migration:**
```ruby
Sequel.migration do
  up do
    # Run data transformation
    DB[:users].where(status: nil).update(status: 'active')
  end

  down do
    # Rollback if needed
  end
end
```

### Debugging

**Using Pry:**
```ruby
# Add to code
require 'pry'
binding.pry

# Execution will pause, allowing you to inspect:
# - Local variables
# - Method calls
# - Object state
```

**Logging:**
```ruby
# Use global LOGGER
LOGGER.info "Processing transaction: #{transaction.id}"
LOGGER.error "Failed to connect to Fiserv: #{e.message}"
LOGGER.debug "Request params: #{params.inspect}"
```

**Database queries:**
```ruby
# Enable SQL logging
DB.loggers << Logger.new($stdout)

# Now all SQL queries will be printed
User.where(email: 'test@example.com').all
# => SELECT * FROM users WHERE email = 'test@example.com'
```

---

## Troubleshooting & Tips

### Common Issues

**1. Bundle install fails:**
```bash
# Clean bundler cache
bundle clean --force
rm -rf vendor/bundle
bundle install

# If nokogiri fails
bundle config build.nokogiri --use-system-libraries
bundle install
```

**2. Database connection errors:**
```bash
# Check PostgreSQL is running
pg_isready

# Check database exists
psql -l | grep webpay

# Create database if missing
createdb webpay_dev

# Run migrations
rake db:migrate
```

**3. Tests failing:**
```bash
# Ensure test database exists
createdb webpay_test

# Run migrations for test
WP_ENV=test rake db:migrate

# Clear VCR cassettes
rm -rf test/fixtures/vcr_cassettes

# Re-run tests
WP_ENV=test rake test
```

**4. Memcached errors:**
```bash
# Install and start memcached
brew install memcached  # macOS
brew services start memcached

# Or
sudo apt-get install memcached  # Linux
sudo systemctl start memcached

# Verify
echo stats | nc localhost 11211
```

**5. CORS errors:**
```bash
# Check .env has correct SPA URL
echo $WP_SPA_HOST_URL

# Enable wildcard for development in config.ru
# origins "*"  # Uncomment this line
```

### Performance Tips

**1. Database indexing:**
- Always index foreign keys
- Index columns used in WHERE clauses
- Use composite indexes for multi-column queries

**2. N+1 queries:**
```ruby
# Bad (N+1):
users.each do |user|
  user.accounts.each { |account| ... }
end

# Good (eager loading):
users = User.eager(:accounts).all
users.each do |user|
  user.accounts.each { |account| ... }
end
```

**3. Caching:**
```ruby
# Cache expensive operations
def self.exchange_rate
  Rails.cache.fetch('exchange_rate', expires_in: 1.hour) do
    FiservService.get_exchange_rate
  end
end
```

**4. Background jobs:**
- Use background jobs for emails
- Use background jobs for external API calls
- Use background jobs for reports

### Code Quality

**Best practices:**
- ✅ Keep methods under 20 lines
- ✅ Keep classes focused (Single Responsibility)
- ✅ Write tests for all business logic
- ✅ Use descriptive variable names
- ✅ Document complex algorithms
- ✅ Extract magic numbers to constants
- ✅ Handle errors gracefully
- ✅ Log important events

**Code review checklist:**
- [ ] Tests pass
- [ ] No SQL injection vulnerabilities
- [ ] Sensitive data masked in logs
- [ ] Database transactions used for financial ops
- [ ] Audit trail created for data changes
- [ ] Validation schemas comprehensive
- [ ] Error handling implemented
- [ ] No hardcoded credentials
- [ ] Constants used instead of magic values
- [ ] Code follows project conventions

---

## Known Technical Debt

### Critical Security Updates (Phase 1 - In Progress)

**1. Nokogiri (CRITICAL):**
```ruby
# Current: 1.13.10
# Target:  1.16.7
# CVEs:    CVE-2022-23476 (CVSS 9.8) - RCE via XML parsing
#          CVE-2024-34459 (CVSS 8.1) - XSS in HTML parsing
```

**2. Rack (HIGH):**
```ruby
# Current: ~> 2.2.6
# Target:  ~> 2.2.9
# CVE:     CVE-2024-25126 (CVSS 7.5) - ReDoS attack
```

**3. dry-validation (BREAKING):**
```ruby
# Current: 0.7.4 (2016!)
# Target:  1.10+
# Impact:  API breaking changes, requires code migration
# Status:  Week 1 Day 3-5
```

**4. ROTP (MEDIUM):**
```ruby
# Current: 3.3.1
# Target:  6.3+
# Impact:  Deprecated, security improvements
# Status:  Week 1 Day 5
```

### Planned Upgrades (Phase 1)

**Ruby Version:**
- Current: 2.6.8 (EOL)
- Target: 3.3
- Timeline: Week 9-10

**Code Duplication:**
- 3 versions of Pagatinu integration
- Should be consolidated into one
- Timeline: Week 13-16

**Architecture:**
- Create webpay-common gem
- Extract shared code
- 30-40% code reduction
- Timeline: Week 13-16

### Documentation Needs

- [ ] API documentation (OpenAPI/Swagger)
- [ ] Deployment guide
- [ ] Monitoring & alerting setup
- [ ] Disaster recovery procedures
- [ ] Performance tuning guide

---

## Quick Reference

### Most Used Commands

```bash
# Development
bundle install                          # Install dependencies
rake db:migrate                         # Run migrations
RUBYOPT=-W0 rerun -- puma -C puma.rb   # Start server
ruby console.rb                         # Interactive console

# Testing
WP_ENV=test rake test                   # All tests
WP_ENV=test rake unit                   # Unit tests only
WP_ENV=test rake integration            # Integration tests only

# Database
rake db:create                          # Create database
rake db:migrate                         # Run migrations
rake db:rollback                        # Rollback one migration
rake db:reset                           # Drop, create, migrate

# Docker
docker-compose up                       # Start services
docker-compose exec development bash    # Enter container
docker-compose -f docker-compose-test.yml up --exit-code-from test  # Run tests
```

### Important Directories

| Path | Purpose |
|------|---------|
| `/routes/private/` | JWT-protected routes |
| `/models/` | Sequel models & business logic |
| `/models/api/` | MPOS API service objects |
| `/services/` | External service integrations |
| `/gateways/` | Payment gateway integrations |
| `/test/integration/` | Integration tests |
| `/db/migrations/` | Database migrations |

### Key Files

| File | Purpose |
|------|---------|
| `webpay.rb` | Main application & routing |
| `models.rb` | Model loader & constants |
| `config.ru` | Rack configuration |
| `Gemfile` | Dependencies |
| `Rakefile` | Test tasks |
| `.env` | Environment variables (gitignored) |

---

## For AI Assistants: Guidelines

### When Working with This Codebase

**ALWAYS:**
- ✅ Backup before making changes (`cp Gemfile Gemfile.backup`)
- ✅ Run tests after changes (`WP_ENV=test rake test`)
- ✅ Use database transactions for financial operations
- ✅ Create audit trails for data changes
- ✅ Validate input with dry-validation schemas
- ✅ Mask sensitive data in logs
- ✅ Follow existing patterns (DStruct, service objects)
- ✅ Write tests for new code
- ✅ Update this file when architecture changes

**NEVER:**
- ❌ Skip testing
- ❌ Commit sensitive data (.env, credentials)
- ❌ Modify multiple components simultaneously
- ❌ Use string interpolation for SQL queries
- ❌ Store passwords in plain text
- ❌ Skip audit trail
- ❌ Make breaking changes without user approval
- ❌ Deploy without running full test suite

### Communication Style

- Be concise and technical
- Ask before destructive actions
- Confirm each step completed
- Report issues immediately
- Provide rollback instructions for risky changes

### Change Management

**For small changes (bug fixes):**
1. Make change
2. Run tests
3. Commit with clear message

**For medium changes (new features):**
1. Discuss approach with user
2. Create branch
3. Implement with tests
4. Run full test suite
5. Create PR with description

**For large changes (refactoring, upgrades):**
1. Read WEBPAY_MASTER_CONTEXT.md for current status
2. Create detailed plan
3. Get user approval
4. Implement incrementally
5. Test extensively
6. Document changes

---

## Version History

- **v1.0** (2025-11-15) - Initial CLAUDE.md created with comprehensive codebase analysis

---

## Additional Resources

- **README.md** - Quick start guide
- **CONTRIBUTING.md** - Development environment setup
- **WEBPAY_MASTER_CONTEXT.md** - Current project status and Phase 1 execution plan
- **Phase 1 Documentation** (if available in /docs)
- **Roda Documentation:** http://roda.jeremyevans.net/
- **Sequel Documentation:** http://sequel.jeremyevans.net/
- **Dry-validation Documentation:** https://dry-rb.org/gems/dry-validation/

---

**END OF CLAUDE.MD**

This file should be read by AI assistants at the start of any work session on this codebase.
