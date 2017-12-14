require 'parallel_rspec/workers.rb'

db_namespace = namespace :db do
  namespace :parallel do
    # desc "Creates the test database"
    task :create => [:load_config] do
      ParallelRSpec::Workers.new.run_test_workers do |worker|
        ActiveRecord::Tasks::DatabaseTasks.create ActiveRecord::Base.configurations['test']
      end
    end

    # desc "Empty the test database"
    task :purge => %w(environment load_config) do
      ParallelRSpec::Workers.new.run_test_workers do |worker|
        ActiveRecord::Tasks::DatabaseTasks.purge ActiveRecord::Base.configurations['test']
      end
    end

    # desc "Recreate the test database from an existent schema.rb file"
    task :load_schema => %w(db:parallel:purge) do
      should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
      begin
        ParallelRSpec::Workers.new.run_test_workers do |worker|
          ActiveRecord::Schema.verbose = false
          ActiveRecord::Tasks::DatabaseTasks.load_schema ActiveRecord::Base.configurations['test'], :ruby, ENV['SCHEMA']
        end
      ensure
        if should_reconnect
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
        end
      end
    end

    # desc "Recreate the test database from an existent structure.sql file"
    task :load_structure => %w(db:parallel:purge) do
      ParallelRSpec::Workers.new.run_test_workers do |worker|
        ActiveRecord::Tasks::DatabaseTasks.load_schema ActiveRecord::Base.configurations['test'], :sql, ENV['SCHEMA']
      end
    end

    # desc "migrate"
    task :migrate => %w(environment) do
      should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
      begin
        ParallelRSpec::Workers.new.run_test_workers do |worker|
          ActiveRecord::Schema.verbose = false
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      ensure
        if should_reconnect
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
        end
      end
    end

    # desc "Recreate the test database from the current schema"
    task :load do
      db_namespace["db:parallel:purge"].invoke
      case ActiveRecord::Base.schema_format
        when :ruby
          db_namespace["parallel:load_schema"].invoke
        when :sql
          db_namespace["parallel:load_structure"].invoke
      end
      db_namespace["parallel:migrate"].invoke
    end

    # desc "Check for pending migrations and load the test schema"
    task :prepare => %w(environment load_config) do
      unless ActiveRecord::Base.configurations.blank?
        db_namespace['parallel:load'].invoke
      end
    end
  end
end
