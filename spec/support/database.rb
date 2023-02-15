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

class User < Sequel::Model(:users)
end
