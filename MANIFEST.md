# WebPay Master - Change Manifest

## 2025-11-02 - OTP Activation Flow Implementation

### Summary
Implemented two-factor authentication for user account activation requiring both an activation token (from email link) and OTP code (from Google Authenticator).

### Changes

#### Backend

**File: `models/user/activate.rb`**
- Added OTP parameter acceptance alongside activation token
- Integrated ROTP::TOTP library for time-based OTP validation
- Added 60-second drift tolerance for OTP verification
- Enhanced error handling with specific messages for invalid OTP/token
- Updated validation schema to require both token and OTP

**Key Code:**
```ruby
# OTP Validation with ROTP
user_otp_code = user[:otp_code]
totp = ROTP::TOTP.new(user_otp_code)

if totp.verify_with_drift(otp, DRIFT, Time.now)
  User.update_without_audit(user[:id], activation_token: nil, active: true)
  return user
else
  context.render_error({otp: ['Invalid OTP code. Please check your authenticator app.']})
  return nil
end
```

#### Frontend

**File: `components/public/activate_user.vue`** (webpay-spa)
- Added OTP input field with real-time validation
- Implemented client-side validation (6 digits, numeric only)
- Added computed property `isOtpValid` for form validation
- Submit button disabled until valid OTP entered
- Error display for invalid OTP codes
- Updated submit method to send both token and OTP to backend

**UI Changes:**
- New label: "Enter OTP Code"
- Help text: "Open your authenticator app (Google Authenticator) and enter the 6-digit code below:"
- Input field with maxlength=6 and numeric-only validation
- Red error message display for validation failures

#### Documentation

**File: `OTP_ACTIVATION_FLOW.md`** (New)
- Complete documentation of OTP activation flow
- API endpoint specifications
- Security considerations (drift tolerance, validation)
- Testing procedures
- Database schema details
- Error handling examples

### API Changes

#### `POST /api/activate-user/:token`

**Request Body (Updated):**
```json
{
  "token": "activation_token_here",
  "otp": "123456"  // NEW: Required 6-digit OTP code
}
```

**New Error Response:**
```json
{
  "otp": ["Invalid OTP code. Please check your authenticator app."]
}
```

### Security

- **OTP Drift Tolerance:** 60 seconds (±1 TOTP period)
- **Validation:** Both token and OTP must be valid
- **Format:** OTP must be exactly 6 numeric digits
- **TOTP Library:** ROTP gem

### Testing

**Test User Reset:**
```sql
DELETE FROM users WHERE email = 'test@example.com';
```

**Manual Test Flow:**
1. Sign up at http://localhost:2222/#!/signup
2. Check email for activation link and QR code
3. Scan QR code with Google Authenticator
4. Click activation link
5. Enter 6-digit OTP code
6. Verify account activated (active=true, activation_token=NULL)

### Database Impact

No schema changes - uses existing fields:
- `users.activation_token` - Cleared on successful activation
- `users.otp_code` - Used for TOTP generation (unchanged)
- `users.active` - Set to true on successful activation

### Backwards Compatibility

**Breaking Change:** Activation now requires OTP code. Existing activation links without OTP validation will fail.

**Migration Path:**
- All users must complete new signup flow
- Old activation tokens remain valid (if not expired)
- Users need to set up Google Authenticator for activation

### Dependencies

- **ROTP gem** - Already installed, used for OTP validation
- **Google Authenticator app** - User requirement for generating OTP codes

### Files Modified

```
webpay-master/v2-current/
├── models/user/activate.rb              [Modified]
└── OTP_ACTIVATION_FLOW.md               [New]

webpay-spa/v2-current/
└── src/components/public/activate_user.vue  [Modified]
```

### Related Documentation

- See `OTP_ACTIVATION_FLOW.md` for detailed implementation docs
- See `views/signup/confirm.erb` for email template with QR code

---

**Author:** Claude Code
**Date:** 2025-11-02
**Version:** 1.0
