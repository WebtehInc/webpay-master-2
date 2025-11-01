require 'rack'
require 'rack/cors'
require 'dalli'

require 'dotenv'
Dotenv.load
require './webpay'

# set memcached
begin
  MEMORY_STORE = Dalli::Client.new(ENV['MEMCACHED_URL'] || 'localhost:11211', :namespace => 'webpay', :compress => true, :expires_in => 5*30)
  MEMORY_STORE.set('test', true)
rescue
  puts 'Memcached client is not runing.'
  exit
end

# set CORS
use Rack::Cors do

  allow do
    origins '*'
    resource '*', :headers => :any,
                  :methods => [:get, :post, :options, :put, :patch],
                  :expose  => ['X-total-count', 'X-per-page']
  end
end

# set assets
use Rack::Static, :urls => ['/data', '/favicon.ico'], :root => 'public', :index => 'index.html'

# run app
run WebPay.freeze.app
