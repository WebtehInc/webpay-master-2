# Docker development environment setup

Start development environment with:

`docker-compose up`

Enter development environment in second terminal:

`docker-compose exec development bash -l`

Once you are in development environment, you can run tests as usual:

`WP_ENV=test bundle exec rake integration`

## Running tests through docker

`docker-compose -f docker-compose-test.yml up --exit-code-from test`

# Classic development environment setup

- install ruby (see Gemfile for correct version)
- set ENV variables in .env for dev and test, see .env.example.txt

  WP_ENV=development
  
  WP_DEV_DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/webpay_dev - postgres example
- create webpay_dev database
- run bundle
- run rake db:migrate
- add webpay entry to host file

  127.0.0.1 webpay
- start with 
  rerun -- puma -v -t 1:1 -b tcp://webpay:4444
- download webpay-spa for frontend

