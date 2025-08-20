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

DB.drop_table? :users, cascade: true
DB.create_table :users do
  primary_key :id
  column :email, :text
end

DB.drop_table? :users_without_pk
DB.create_table :users_without_pk do
  column :id, :integer
  column :email, :text
end

DB.drop_table? :complex_users
DB.create_table :complex_users do
  column :geo, :text
  column :nick, :text

  primary_key %i[geo nick]
end

DB.drop_table? :user_tokens
DB.create_table :user_tokens do
  primary_key :id
  foreign_key :user_id, :users
end

class User < Sequel::Model(:users)
  def skip_table_sync?
    false
  end
end

class UserWithoutPk < Sequel::Model(:users_without_pk)
  def skip_table_sync?
    false
  end
end

class ComplexUser < Sequel::Model(:complex_users)
  def skip_table_sync?
    false
  end
end

class UserToken < Sequel::Model(:user_tokens)
  many_to_one :user, class: "User", key: :user_id

  def skip_table_sync?
    false
  end
end
