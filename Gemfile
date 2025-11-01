source "https://rubygems.org"

# ruby version
ruby "3.3.0"

# tools
gem "rake", "~> 13.0", ">= 13.0.6"
gem "foreman"
gem "rerun"
gem "irb"

# server
gem "puma", "~> 6.4", ">= 6.4.3"
gem "puma_worker_killer"

# db
gem "sequel"
gem "sequel_pg", require: "sequel"
gem "philtre"
gem "pg"

# faster JSON
gem "oj"

# web
gem "rack", "~> 3.1"
gem "rack-cors", "~> 2.0"
gem "roda"
gem "roda-symbolized_params"
gem "tilt"
gem "useragent"
gem "facets"

# jwt
gem "jwt"
gem "bcrypt"

# totp
gem "rotp", "3.3.1" # v4.0 will break otp codes
gem "rqrcode"

# memcached
gem "dalli"

# validation, THESE ARE ANCIENT
# d_struct should be updated
gem "dry-configurable", "0.1.4"
gem "dry-equalizer", "0.2.0"
gem "dry-logic", "0.2.2"
gem "dry-container", "0.3.1"
gem "dry-types", "0.7.1"
gem "dry-validation", "0.7.4"
gem "d_struct" # depends on above dry gems

# console
gem "tty-prompt"
gem "tty-command"

# iban
gem "ibanizator"

# for HTTP apis
gem "faraday", "~> 2.0"
gem "activesupport", "~> 7.0", require: false
gem "builder"
gem "nokogiri", "~> 1.16", ">= 1.16.5"

# mail
gem "mail"

# pry, for debugs
gem "pry"
gem "awesome_print"

group :development_dependencies do
  # shim to load environment variables from .env into ENV in development.
  gem "dotenv" # development & tests

  # minitest
  gem "minitest"
  gem "webmock"
  gem "vcr"
  gem "m" # this disappeared somehow

  gem "rack-test"
  gem "faker"
end
