# frozen_string_literal: true

require "logger"

begin
  db_name = "umbrellio_utils_test"
  DB = Sequel.connect(ENV.fetch("DB_URL", "postgres://localhost/#{db_name}"))
rescue Sequel::DatabaseConnectionError => error
  puts error
  abort "You probably need to create a test database. " \
        "Try running the following command: `createdb #{db_name}`"
end

DB.logger = Logger.new("log/db.log")

Sequel::Model.db = DB

DB.extension :batches

DB.drop_table? :users
DB.create_table :users do
  primary_key :id
  column :email, :text
end

DB.drop_table? :complex_users
DB.create_table :complex_users do
  column :geo, :text
  column :nick, :text

  primary_key %i[geo nick]
end

class User < Sequel::Model(:users)
  def skip_table_sync?
    false
  end
end

class ComplexUser < Sequel::Model(:complex_users)
  def skip_table_sync?
    false
  end
end
