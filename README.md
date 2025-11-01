# WebPay

Online banking with mPOS backend

## Setup

To see how to setup your development environment, see CONTRIBUTING.md

## Development

``` bash
## env
export WP_ENV=development
export WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_dev

## serve
RUBYOPT="-W0" rerun -- puma -v -t 2:2 -b tcp://webpay:4444
RUBYOPT="-W0" rerun -- puma -C puma.rb -b tcp://webpay:4444
```

Notes:

- uncoment stdout_redirect if using `-C puma.rb` to see logs
- enable cors in `config.ru` with `origins "*"`
- install mailcatcher gem to work with emails

### Test

``` bash
## env
export WP_ENV=test
export WP_TEST_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_test

## run test
RUBYOPT=-W0 rake test
```
