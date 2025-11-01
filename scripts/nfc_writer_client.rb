require 'http'

SERVER_ROOT = 'https://test-webpay-admin.psbbanknv.com/'
init_writer_path = 'api/issuing/init-nfc-writer'
configure_nfc_writer_path = 'api/issuing/configure-nfc-writer'
download_card_data_path = 'api/issuing/download-card-data'

access_token = 'ub3wj36dwt'
nfc_writer_api_key = 'abc_123!'

def api_call(path, request)
  puts
  puts "API URL: #{SERVER_ROOT + path}\n\n"
  puts '**** request'
  puts request.to_json
  puts
  response = HTTP.post(SERVER_ROOT + path, json: request)
  puts '**** response'
  # puts 'RAW: ' + response.inspect; puts
  puts response.body
  puts
  return JSON.parse response.body
end


# call init writer API
request = {access_code: '112059', otp_code: '921505'}
api_call(init_writer_path, request)

# call configure writer API
systan = rand(99999999).to_s
request = {access_token: access_token, systan: systan, digest: Digest::SHA512.hexdigest(nfc_writer_api_key + access_token + systan)}
api_call(configure_nfc_writer_path, request)

# call download card data
access_code = '136683'; otp_code = '977865'
request = { access_code: access_code, otp_code: otp_code,
            card_serial_number: '1234567890', access_token: access_token,
            digest: Digest::SHA512.hexdigest(nfc_writer_api_key + access_code + otp_code)}
api_call(download_card_data_path, request)
