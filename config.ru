require "rack"
require "rack/cors"

# set secure headers
require_relative "secure_headers"
use Rack::SecureHeaders

# set CORS
use Rack::Cors do
  allow do
    # origins "*" # use in dev for localhost
    origins ENV["WP_SPA_HOST_URL"].chomp("#!").to_s
    resource "*", :headers => :any, :methods => [:get, :post, :options, :put, :patch], :expose => ["X-total-count", "X-per-page"]
  end
end

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
