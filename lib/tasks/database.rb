namespace :db do
  desc "Run migrations"
  task :migrate, [:version] do |t, args|

    # NOTE: use this for initial migration instead of task invoke line that loads the app
    # require "sequel"
    # DB = Sequel.connect(ENV.delete('WP_TEST_DATABASE_URL'))

    Rake::Task[:app].invoke
    Sequel.extension :migration
    db = DB # from app task
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, "db/migrations", target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(db, "db/migrations")
    end
  end
end
