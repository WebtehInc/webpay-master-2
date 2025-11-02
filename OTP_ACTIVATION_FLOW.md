# OTP Activation Flow - Dokumentacija

## Pregled

User activation proces zahteva **dva faktora autentikacije**:
1. **Activation Token** - poslan u activation linku putem emaila
2. **OTP Code** - 6-cifren kod iz Google Authenticator aplikacije

## Proces Aktivacije

### 1. Signup

Kada se korisnik registruje (`POST /api/signup`):

```ruby
# models/user/signup.rb:24-28
if user
  Mailer.sendmail("/signup/confirm", user)
  context.render_success
end
```

**Email sadrži:**
- Activation link sa activation_token-om
- QR kod za Google Authenticator setup

### 2. Email Confirmation

Email template (`views/signup/confirm.erb`):

```erb
<!-- Activation Link -->
<a href="http://localhost:2222/#!/activate-user/{activation_token}">
  Activate Account
</a>

<!-- QR Code za Google Authenticator -->
<div>
  <%= qr_code.as_html %>
</div>
```

### 3. Activation Page

Frontend komponenta (`components/public/activate_user.vue`):

**Funkcionalnost:**
- Učitava user podatke pomoću activation token-a (GET `/api/activate-user/:token`)
- Prikazuje formu sa OTP input poljem
- Validira OTP format (6 cifara, samo brojevi)
- Submit button je disabled dok OTP nije validan

**Validation:**
```javascript
// Real-time OTP validation
validateOtp () {
  this.otp = this.otp.replace(/\D/g, '')  // Samo brojevi
  if (this.errors.otp) {
    this.errors.otp = null
  }
}

// Computed property
isOtpValid () {
  return this.otp && /^\d{6}$/.test(this.otp)
}
```

### 4. Backend Validation

Backend (`models/user/activate.rb`):

```ruby
# Validacija OTP-a pomoću ROTP
user_otp_code = user[:otp_code]
totp = ROTP::TOTP.new(user_otp_code)

# Verifikacija sa drift tolerance-om (60 sekundi)
if totp.verify_with_drift(otp, DRIFT, Time.now)
  User.update_without_audit(user[:id], activation_token: nil, active: true)
  return user
else
  context.render_error({otp: ['Invalid OTP code. Please check your authenticator app.']})
  return nil
end
```

**DRIFT parametar:**
- Dozvoljava 60-sekundnu toleranciju na OTP kod
- OTP kodovi se generišu svakih 30 sekundi
- Time.now koristi trenutno vreme za verifikaciju

### 5. Uspešna Aktivacija

Kada su oba faktora validna:
- User se aktivira (`active: true`)
- Activation token se briše (`activation_token: nil`)
- Korisnik se automatski loguje
- Redirekcija na `/home`

## API Endpoints

### GET `/api/activate-user/:token`

**Svrha:** Učitavanje user podataka za prikaz na activation stranici

**Response:**
```json
{
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe"
}
```

### POST `/api/activate-user/:token`

**Svrha:** Aktivacija naloga sa OTP verifikacijom

**Request Body:**
```json
{
  "token": "xikdnnc6kqetnkk5",
  "otp": "123456"
}
```

**Success Response:**
```json
{
  "user": {...},
  "jwt_token": "...",
  ...
}
```

**Error Response:**
```json
{
  "otp": ["Invalid OTP code. Please check your authenticator app."]
}
```

ili

```json
{
  "token": ["Invalid activation token."]
}
```

## Database Schema

### users table

Relevantna polja za OTP activation:

```sql
activation_token VARCHAR  -- Token poslan u activation linku
otp_code         VARCHAR  -- Secret za ROTP TOTP generisanje
active           BOOLEAN  -- Da li je user aktiviran
```

**Lifecycle:**
1. **Signup:** `activation_token` = random, `otp_code` = random, `active` = false
2. **Activation:** `activation_token` = NULL, `otp_code` = nepromenjeno, `active` = true

**Napomena:** `otp_code` ostaje trajno u bazi jer se koristi za svaki budući login (OTP za 2FA).

## Security

### OTP Drift Tolerance

```ruby
DRIFT = 1*60  # 60 sekundi
```

**Razlog:**
- OTP kodovi se generišu svakih 30 sekundi
- Korisnik može imati clock skew između telefona i servera
- 60-sekundna tolerancija pokriva ±1 period (30s pre, 30s posle)

### Validation Schema

```ruby
MyValidationSchema = Dry::Validation.Schema do
  key(:token) do |token|
    token.filled?
  end

  key(:otp) do |otp|
    otp.filled? & otp.format?(/^\d{6}$/)
  end
end
```

**Validacije:**
- Token mora biti present i non-empty
- OTP mora biti tačno 6 cifara (samo brojevi)

## Testing

### Manual Test Flow

1. **Signup:**
   ```
   http://localhost:2222/#!/signup
   ```

2. **Check Email:**
   - Klikni activation link
   - Skenuj QR kod sa Google Authenticator app-om

3. **Activation:**
   ```
   http://localhost:2222/#!/activate-user/{token}
   ```
   - Unesi 6-cifren OTP kod iz app-a
   - Klikni "Activate account"

4. **Verify:**
   ```sql
   SELECT id, email, active, activation_token
   FROM users
   WHERE email = 'test@example.com';
   ```

   Očekivano:
   - `active` = true
   - `activation_token` = NULL

### Database Reset for Testing

```sql
-- Obriši test usera
DELETE FROM users WHERE email = 'test@example.com';

-- Ili reset activation fielda
UPDATE users
SET activation_token = 'new_token_here',
    active = false
WHERE email = 'test@example.com';
```

## Error Handling

### Invalid OTP

**Frontend:**
```javascript
if (!this.isOtpValid) {
  this.errors.otp = ['Please enter a valid 6-digit OTP code']
  return
}
```

**Backend:**
```ruby
if totp.verify_with_drift(otp, DRIFT, Time.now)
  # Success
else
  puts 'Invalid OTP code.'
  context.render_error({otp: ['Invalid OTP code. Please check your authenticator app.']})
  return nil
end
```

### Invalid Token

```ruby
if user = User.find_all_values_by_attrs(activation_token: token)
  # Proceed with OTP validation
else
  puts 'Invalid token.'
  context.render_error({token: ['Invalid activation token.']})
  return nil
end
```

## Files Modified

### Backend
- `/models/user/activate.rb` - OTP validation logic

### Frontend
- `/components/public/activate_user.vue` - OTP input field & validation

### Email Template
- `/views/signup/confirm.erb` - QR code i activation link (već postojalo)

## Dependencies

- **ROTP** gem - Time-based One-Time Password implementation
- **Google Authenticator** app - Korisnička aplikacija za generisanje OTP kodova

## Configuration

`.env` file:

```bash
OTP_TTL=300  # OTP cache TTL u sekundama (za verify_otp endpoint)
```

**Napomena:** OTP_TTL se koristi za `/api/verify-otp` endpoint (post-login verification), ne za activation.

---

**Kreirao:** Claude Code
**Datum:** 2025-11-02
**Verzija:** 1.0
