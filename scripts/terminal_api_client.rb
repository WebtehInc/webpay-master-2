require 'http'
require 'awesome_print'

API_SERVER_ROOT   = 'http://webpay:4444'
INIT_SERVER_ROOT   = 'http://webpay:5555'

# API_SERVER_ROOT = 'https://test-webpay.psbbanknv.com'
# INIT_SERVER_ROOT = 'https://test-webpay-admin.psbbanknv.com'

# setup terminal
access_token  = 't5gpxi4nrvxla7hc'

# OLD manual method
terminal_key  = '2zugaptan2'

# NEW API Init method
# visit INIT_SERVER_ROOT/api/terminal/prepare-init-data/terminal_id/terminal_key to get access_code and otp_code
access_code = '913061'
otp_code    = '216084'

# terminal cashiers
manager_id    = 72      # dessie
manager_pin   = '9429'
cashier_id    = 73      # jonhhy
cashier_pin   = '6061'

# setup services values
bill_operator_code      = 'ae'
bill_customer_number    = '11111'
prepaid_operator_code   = 'pa'
prepaid_customer_number = '04229889888'
voucher_name            = 'Chippie 10'
cashier_name            = 'Cashier #' + rand(999999).to_s
card_number             = '4400021811181111'
card_pin                = '2222'


############ init terminal
# download terminal params - terminal_id, terminal_key, tmk, tmk_kcv
init_request = {access_code: access_code, otp_code: otp_code}
init_api_url = INIT_SERVER_ROOT + '/api/terminal/init'
puts
puts "API URL: #{init_api_url}"
puts "Init terminal request: #{init_request}"
init_response = HTTP.post(init_api_url, json: init_request)
init_data = JSON.parse init_response.body
puts "Init terminal response: #{init_data}"
if init_response.status.code == 422
  exit
else
  terminal_id  = init_data['terminal_id']
  terminal_key = init_data['terminal_key']
  tmk          = init_data['tmk']
  tmk_kcv      = init_data['tmk_kcv']
end

def api_call(path, request, request_digest_keys = nil, response_digest_keys = nil)
  puts
  request = request.merge!(api_version: "1.0.0.", application_version: "1.0.0.")
  puts "API URL: #{API_SERVER_ROOT + path}"; puts '-' * 100
  puts "Request digest formula: Digest(#{request_digest_keys.join(' + ')})" if request_digest_keys
  puts
  ap request, color: {hash: :pale}
  puts
  response = HTTP.post(API_SERVER_ROOT + path, json: request)
  puts 'RAW response: ' + response.inspect; puts
  body = JSON.parse response.body
  puts  "Response digest formula: Digest(#{response_digest_keys.join(' + ')})" if response_digest_keys
  puts; puts "JSON: " + response.body; puts
  ap body, color: {hash: :cyan}
  puts
  return body
end

def calculate_digest(*args)
   Digest::SHA512.hexdigest args.join
end

############ configure terminal
# we save services_batch_number from response for close-services-batch call later
digest_params = { terminal_key: terminal_key, access_token: access_token}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values)}
response      = api_call('/api/configure-terminal', request, digest_params.keys, [:terminal_key, :access_token, :config_version])
services_batch_number = response['services_batch_number']


############ create cashier
# API CHANGE NOTE: cashier_id of new cashier is returned in response
digest_params = { terminal_key: terminal_key, access_token: access_token, full_name: cashier_name}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), full_name: cashier_name, manager: false,
                  cashier_pin: manager_pin, manager_id: manager_id}
response      = api_call('/api/create-cashier', request, digest_params.keys, [:terminal_key, :access_token, :pin])


############ update cashier
# target cashier is previous one
digest_params = { terminal_key: terminal_key, access_token: access_token, cashier_id: response['cashier_id']}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), cashier_id: response['cashier_id'],
                  active: false , manager: true, cashier_pin: manager_pin, manager_id: manager_id}
api_call('/api/update-cashier', request, digest_params.keys, [:terminal_key, :access_token, :active])


############ change cashier pin
# target cashier is previous one
digest_params = { terminal_key: terminal_key, access_token: access_token, cashier_id: response['cashier_id']}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), cashier_id: response['cashier_id'],
                  cashier_pin: manager_pin, manager_id: manager_id}
api_call('/api/change-cashier-pin', request, digest_params.keys, [:terminal_key, :access_token, :pin])


############ bill payment
# API CHANGE NOTE: customer_balance is removed from response - response digest is now digest(terminal_key + access_token + id)
digest_params = { terminal_key: terminal_key, access_token: access_token, operator_code: bill_operator_code, customer_number: bill_customer_number,
                  amount: '1234', currency: 'ANG', systan: rand(99999999)}
request       = { access_token: access_token, operator_code: digest_params[:operator_code], digest: calculate_digest(*digest_params.values),
                  cashier_pin: cashier_pin, cashier_id: cashier_id, customer_number: digest_params[:customer_number],
                  amount: digest_params[:amount], currency: digest_params[:currency], payment_method: 'card', payment_method_type: 'debit',
                  systan: digest_params[:systan], client_datetime: Time.now}
response      = api_call('/api/bill-payment', request, digest_params.keys, [:terminal_key, :access_token, :id])


############ reverse bill payment
# API CHANGE NOTE: customer_balance is removed from response
# reversing transaction is previous one - we are using its id, amount and systan
digest_params = { terminal_key: terminal_key, access_token: access_token, original_id: response['id'], systan: digest_params[:systan], amount: digest_params[:amount]}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), cashier_pin: manager_pin, cashier_id: manager_id,
                  original_id: response['id'], amount: digest_params[:amount], systan: digest_params[:systan], client_datetime: Time.now}
api_call('/api/reverse-bill-payment', request, digest_params.keys, [:terminal_key, :access_token, :id])


############ sell voucher
digest_params = { terminal_key: terminal_key, access_token: access_token, name: voucher_name, systan: rand(99999999)}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), name: voucher_name, systan: digest_params[:systan],
                  cashier_pin: cashier_pin, cashier_id: cashier_id, client_datetime: Time.now, payment_method: 'cash',  payment_method_type: ''}
api_call('/api/sell-voucher', request, digest_params.keys, [:terminal_key, :access_token, :voucher_code])


############ sell prepaid
digest_params = { terminal_key: terminal_key, access_token: access_token, operator_code: prepaid_operator_code, customer_number: prepaid_customer_number,
                  amount: '1234', currency: 'ANG', systan: rand(99999999)}
request       = { access_token: access_token, operator_code: digest_params[:operator_code], digest: calculate_digest(*digest_params.values),
                  cashier_pin: cashier_pin, cashier_id: cashier_id, customer_number: digest_params[:customer_number],
                  amount: digest_params[:amount], currency: digest_params[:currency], payment_method: 'card', payment_method_type: 'debit',
                  systan: digest_params[:systan], client_datetime: Time.now}
api_call('/api/sell-prepaid', request, digest_params.keys, [:terminal_key, :access_token, :prepaid_code])


############ top up
# API CHANGE NOTE: account_number is replaced with card_number which is read from NFC card, card_pin is a new input variable
# API CHANGE NOTE: account_balance removed from response - response digest is now digest(terminal_key + access_token + id)
digest_params = { terminal_key: terminal_key, access_token: access_token, card_number: card_number, amount: '1234', currency: 'ANG', systan: rand(99999999)}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), cashier_pin: cashier_pin, cashier_id: cashier_id, card_pin: card_pin,
                  card_number: card_number, amount: digest_params[:amount], currency: digest_params[:currency], systan: digest_params[:systan], client_datetime: Time.now}
response      =  api_call('/api/top-up', request, digest_params.keys, [:terminal_key, :access_token, :id])


############ reverse top up
# reversing transaction is previous one - we are using its id, amount and systan
digest_params = { terminal_key: terminal_key, access_token: access_token, original_id: response['id'], systan: digest_params[:systan], amount: digest_params[:amount]}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), original_id: response['id'], cashier_pin: manager_pin, cashier_id: manager_id,
                  amount: digest_params[:amount], systan: digest_params[:systan], client_datetime: Time.now}
api_call('/api/reverse-top-up', request, digest_params.keys, [:terminal_key, :access_token, :original_id])


############ sale wallet
# NOTE: this is new API endpoint, input and output spec is the same as for top-up
digest_params = { terminal_key: terminal_key, access_token: access_token, card_number: card_number, amount: '1234', currency: 'ANG', systan: rand(99999999)}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values), cashier_pin: cashier_pin, cashier_id: cashier_id, card_pin: card_pin,
                  card_number: card_number, amount: digest_params[:amount], currency: digest_params[:currency], systan: digest_params[:systan], client_datetime: Time.now}
api_call('/api/sale-wallet', request, digest_params.keys, [:terminal_key, :access_token, :id])


############ close services batch
digest_params = { terminal_key: terminal_key, access_token: access_token, services_batch_number: services_batch_number}
request       = { access_token: access_token, digest: calculate_digest(*digest_params.values),
                  cashier_pin: manager_pin, cashier_id: manager_id, services_batch_number: services_batch_number}
api_call('/api/close-services-batch', request, digest_params.keys, [:terminal_key, :access_token, :services_batch_number])
