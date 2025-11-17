# country codes, see public/data/countries
COUNTRY_CODES = ["AF", "AL", "DZ", "AS", "AD", "AO", "AI", "AQ", "AG", "AR", "AM", "AW", "AU", "AT", "AZ", "BS", "BH", "BD", "BB", "BY", "BE", "BZ", "BJ", "BM", "BT", "BO", "BQ", "BA", "BW", "BV", "BR", "IO", "BN", "BG", "BF", "BI", "KH", "CM", "CA", "CV", "KY", "CF", "TD", "CL", "CN", "CX", "CC", "CO", "KM", "CG", "CD", "CK", "CR", "HR", "CU", "CW", "CY", "CZ", "CI", "DK", "DJ", "DM", "DO", "EC", "EG", "SV", "GQ", "ER", "EE", "ET", "FK", "FO", "FJ", "FI", "FR", "GF", "PF", "TF", "GA", "GM", "GE", "DE", "GH", "GI", "GR", "GL", "GD", "GP", "GU", "GT", "GG", "GN", "GW", "GY", "HT", "HM", "VA", "HN", "HK", "HU", "IS", "IN", "ID", "IR", "IQ", "IE", "IM", "IL", "IT", "JM", "JP", "JE", "JO", "KZ", "KE", "KI", "KP", "KR", "KW", "KG", "LA", "LV", "LB", "LS", "LR", "LY", "LI", "LT", "LU", "MO", "MK", "MG", "MW", "MY", "MV", "ML", "MT", "MH", "MQ", "MR", "MU", "YT", "MX", "FM", "MD", "MC", "MN", "ME", "MS", "MA", "MZ", "MM", "NA", "NR", "NP", "NL", "AN", "NC", "NZ", "NI", "NE", "NG", "NU", "NF", "MP", "NO", "OM", "PK", "PW", "PS", "PA", "PG", "PY", "PE", "PH", "PN", "PL", "PT", "PR", "QA", "RO", "RU", "RW", "RE", "BL", "SH", "KN", "LC", "MF", "PM", "VC", "WS", "SM", "ST", "SA", "SN", "RS", "SC", "SL", "SG", "SX", "SK", "SI", "SB", "SO", "ZA", "GS", "SS", "ES", "LK", "SD", "SR", "SJ", "SZ", "SE", "CH", "SY", "TW", "TJ", "TZ", "TH", "TL", "TG", "TK", "TO", "TT", "TN", "TR", "TM", "TC", "TV", "UG", "UA", "AE", "GB", "US", "UM", "UY", "UZ", "VU", "VE", "VN", "VG", "VI", "WF", "EH", "YE", "ZM", "ZW", "AX"]

# for hash masking
SENSITIVE_ATTRS = ["password", "digest", "otp", "cashier_pin", "pan", "track2", "pin_block", "cvv", "expiration_date", "image", "file", "token"]

# accepted cards
ACCEPTED_CARDS = { visa: "Visa", master: "MasterCard" }

# app env
APP_ENV = {
  build: `git rev-parse HEAD`.chomp[0..6],
  migration: DB[:schema_info].first[:version],
  time: `git log -1 --format=%cd`.chomp,
}

# https://www.iban.com/currency-codes.html
CURRENCY_CODES = { "USD" => 840, "EUR" => 978, "XCG" => 532 }

# user types
USER_TYPES = { basic: "Basic", standard: "Standard" }
DOCUMENT_TYPES = { national_id: "National ID", passport: "Passport", utility_bill: "Utility bill" }

# account types
WALLET_ACCOUNT_TYPES = { personal: "Personal wallet account", business: "Business wallet account" }
BANK_ACCOUNT_TYPES = { current: "Current account", savings: "Savings account" }

# mpos services payment methods and types - sent in mpos config api
MPOS_CARD_PAYMENT_METHOD_TYPES = [{ payment_method_type: :credit, name: "Credit card" },
                                  { payment_method_type: :debit, name: "Debit card" }]

MPOS_CHECK_PAYMENT_METHOD_TYPES = [{ payment_method_type: :sft, name: "SFT bank" },
                                   { payment_method_type: :giro, name: "Girobank" },
                                   { payment_method_type: :caribe, name: "Banko di Caribe" },
                                   { payment_method_type: :vida, name: "Vida Nova Bank" },
                                   { payment_method_type: :mcb, name: "MCB bank" },
                                   { payment_method_type: :fcib, name: "FCIB bank" },
                                   { payment_method_type: :orco, name: "Orco bank" },
                                   { payment_method_type: :rbc, name: "RBC bank" }]

# map methods and their types
MPOS_PAYMENT_METHODS_AND_TYPES = [{ payment_method: :cash, name: "Cash", types: [] },
                                  { payment_method: :card, name: "Card", types: MPOS_CARD_PAYMENT_METHOD_TYPES },
                                  { payment_method: :check, name: "Check", types: MPOS_CHECK_PAYMENT_METHOD_TYPES }]
# wallet transaction types
WALLET_TRANSACTION_TYPES = { bill: "Bill payment",
                             voucher: "Voucher payment",
                             top_up: "Top up",
                             top_up_reversal: "Top up reversal",
                             prepaid: "Pagatinu payment",
                             sale_wallet: "Wallet sale",
                             transfer: "Wallet to wallet transfer",
                             transfer_wallet_to_bank: "Wallet to bank transfer",
                             transfer_bank_to_wallet: "Bank to wallet transfer",
                             transfer_bank_to_bank: "Bank to bank transfer",
                             bank_balance_inquiry: "Balance inquiry" }
# card auth types
# authorize, purchase, capture, refund or void -  switch types
CARD_TRANSACTION_TYPES = { card_authorization: "POS card authorization",
                           card_sale: "POS card sale",
                           card_capture: "POS card capture",
                           card_refund: "POS card refund",
                           card_void: "POS card void",
                           card_adjustment: "POS card adjustment",
                           card_reversal: "POS card reversal" }

# services transaction types
MPOS_TRANSACTION_TYPES = { bill_mpos: "POS bill payment",
                           bill_reversal_mpos: "POS bill payment reversal",
                           voucher_mpos: "POS voucher payment",
                           top_up_mpos: "POS top up",
                           top_up_reversal_mpos: "POS top up reversal",
                           sale_wallet_mpos: "POS wallet sale",
                           prepaid_mpos: "POS pagatinu payment",
                           service_mpos: "POS service payment" }.merge(CARD_TRANSACTION_TYPES)

# fees for wallet and services types
FEES_TRANSACTION_TYPES = { bill_fee: "Bill payment fee", voucher_fee: "Voucher payment fee",
                           top_up_fee: "Top up fee", prepaid_fee: "Pagatinu payment fee",
                           transfer_fee: "Wallet to wallet transfer fee",
                           transfer_wallet_to_bank_fee: "Wallet to bank transfer fee",
                           transfer_bank_to_wallet_fee: "Bank to wallet transfer fee",
                           transfer_bank_to_bank_fee: "Bank to bank transfer fee" }

ALL_TRANSACTION_TYPES = WALLET_TRANSACTION_TYPES.merge(MPOS_TRANSACTION_TYPES).merge(FEES_TRANSACTION_TYPES)

CONSTANTS_FOR_SPA = {

  # transactions
  trx_payment_methods: { cash: { name: "Cash", types: {} },
                         card: { name: "Card", types: { credit: "Credit card", debit: "Debit card" } },
                         check: { name: "Check", types: MPOS_CHECK_PAYMENT_METHOD_TYPES.reduce({}) { |acc, (k, v)| acc.update(k[:payment_method_type] => k[:name]) } } },

  trx_transaction_types: { all: ALL_TRANSACTION_TYPES,
                           wallet: { name: "Wallet transactions", types: WALLET_TRANSACTION_TYPES },
                           mpos: { name: "POS transactions", types: MPOS_TRANSACTION_TYPES },
                           fees: { name: "Fee transactions", types: FEES_TRANSACTION_TYPES } },

  trx_statuses: { approved: "Approved", declined: "Declined" },
  trx_types: { debit: "Debit", credit: "Credit" },

  # users
  document_types: DOCUMENT_TYPES,
  document_statuses: { pending: "Pending", approved: "Approved", rejected: "Rejected" },
  user_titles: { mr: "Mr.", ms: "Ms." },
  user_types: USER_TYPES,

  # accounts
  wallet_account_types: WALLET_ACCOUNT_TYPES,
  bank_account_types: BANK_ACCOUNT_TYPES,
  account_types: WALLET_ACCOUNT_TYPES.merge(BANK_ACCOUNT_TYPES),
}

# json settings
USER_SETTINGS = { accounts: {}, notifications: {} }
ACCOUNT_SETTINGS = { low_stock: {} }

# helpers
require "./utils"

# JWT blacklist service
require "./lib/jwt_blacklist"

# sequel
require "./db/database"

# input validation
require "d_struct"
require "./models/schema_predicates"

# DB models
# user that log in
require "./models/user/user"

# accounts i.e. wallets
require "./models/account/account"
require "./models/account/voucher_stock"

# cards
require "./models/card/card"

# terminals
require "./models/terminal/terminal"
require "./models/terminal/cashier"

# transactions
require "./models/transaction/transaction"
require "./models/transaction/reversal"

# simple pages (terms, about, etc ...)
require "./models/page"

# audits, polymorfic associations to other models
require "./models/audit"

# events, logs errors and suspicious activity
require "./models/event"

# settings
require "./models/setting"
require "./models/memory_cache/cache"

# template for vouchers and voucher stock
require "./models/product"

# messages
require "./models/message/message"

# uploads
require "./models/document"

# services
require "./services/core_bank_service"
require "./services/fiserv_service"
require "./services/card_authorization_service"

require "./services/prepaid_service" # 1st pagatinu
require "./services/pagatinu_service" # 2nd pagatinu
require "./services/pagatinu_rest_service" # 3rd pagatinu
require "./services/curgas_service"
require "./services/tax_service"

# fees
require "./models/fee"

# limits
require "./models/limit"

# operators/services models
require "./models/operator/operator"
require "./models/voucher/voucher"
require "./models/customer/customer"
require "./models/services_lodgments"

### mpos api
require "./models/api/helpers/common"
require "./models/api/common_terminal_validators"
require "./models/api/configure_terminal"
require "./models/api/close_services_batch"
require "./models/api/download_file"
require "./models/api/reverse_on_timeout"
require "./models/api/retry_transaction"

# topup
require "./models/api/top_up"
require "./models/api/reverse_top_up"

# sale
require "./models/api/sale_wallet"

# bill payment
require "./models/api/bill_payment"
require "./models/api/reverse_bill_payment"
require "./models/api/bill_balance_inquiry"

# voucher
require "./models/api/sell_voucher"
require "./models/api/sell_prepaid"

# cashiers
require "./models/api/create_cashier"
require "./models/api/update_cashier"
require "./models/api/change_cashier_pin"
require "./models/api/check_cashier_pin"

# card processing
require "./models/api/generate_csk"
require "./models/api/authorize"

# services
require "./models/api/curgas_service"
require "./models/api/pagatinu_service"
require "./models/api/pagatinu_rest_service"
require "./models/api/tax_service"
