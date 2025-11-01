require "logger"

# simple logger for use outside rack (migrations, irb, scripts ...)
Object.const_defined?("LOGGER") ? LOGGER : LOGGER = Logger.new($stdout)

# load environment
# delete variable from the environment, so it isn't accidently passed to subprocesses.
if ENV["WP_ENV"] == "development"
  require_relative "development"
  require "./gateways/dummy"
  DB = Sequel.connect(ENV.delete("WP_DEV_DATABASE_URL"), max_connections: 10)
end

if ENV["WP_ENV"] == "test"
  require_relative "test"
  require "./gateways/dummy"
  DB = Sequel.connect(ENV.delete("WP_TEST_DATABASE_URL"))
end

if ENV["WP_ENV"] == "production"
  require_relative "production"
  DB = Sequel.connect(ENV.delete("WP_PROD_DATABASE_URL"), max_connections: 10)
  LOGGER.level = Logger::WARN
end

# TODO: make this dynamic / configurable somehow
require "./gateways/jsecmodule"
require "./gateways/infoswitch"
require "./lib/pagatinu_client"
require "./lib/fiserv_client"

ENV.delete("WP_ENV")

# manage dead connections
DB.extension(:connection_validator)
DB.pool.connection_validation_timeout = 1600

# init memory cache store
require "./models/memory_cache/store"

# bg jobs
# require 'que'
# Que.connection = DB

module Environment
  def self.included(base)
    base.extend CurrentEnvironment
    base.current_environment!
    WebPay.opts[:wp_env] = base.environment
    puts "  => included /env/#{base.environment}.rb file"
    puts "  => running in #{base.environment} environment ..."
  end
end
