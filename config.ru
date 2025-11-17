require "rack"
require "rack/cors"

# load env settings from file
require 'dotenv'
Dotenv.load

# set CORS (must be first to handle preflight requests)
use Rack::Cors do
  allow do
    origins "*" # use in dev for localhost
    # origins ENV["WP_SPA_HOST_URL"].chomp("#!").to_s
    resource "*", :headers => :any, :methods => [:get, :post, :options, :put, :patch, :delete], :expose => ["X-total-count", "X-per-page"]
  end
end

# RATE LIMITING - MUST BE LOADED BEFORE APP
require_relative 'config/initializers/rack_attack'
use Rack::Attack

# set secure headers
require_relative "secure_headers"
use Rack::SecureHeaders

# set assets
use Rack::Static, :urls => ["/data", "/static", "/favicon.ico"], :root => "public"
use Rack::Static, :urls => { "/" => "index.html" }, :root => "public"

# set logger
LOGGER = Logger.new STDOUT

# load app
puts "* Starting webpay app ..."
unless ENV["WP_ENV"]
  puts "WP_ENV is not set"
  exit
end
require_relative "webpay"

# run app
run WebPay.freeze.app
