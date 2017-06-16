#!/usr/bin/env ruby
require "mysql2"

require "optparse"
require "json"
require "digest"

def main
  desired_state = parse_input_to_desired_state(JSON.load(STDIN.read))

  credentials = parse_credentials
  credentials[:database] = "mysql"

  client = Mysql2::Client::new(credentials)

  apply_configuration(client, desired_state)
end

def apply_configuration(client, desired_state)
  migrate_mysql_schema!(client)

  desired_user_statements = generate_desired_user_grants(desired_state)
  actual_user_statements = fetch_user_statements(client)

  to_remove = actual_user_statements.reject { |grant| desired_user_statements.include?(grant) }
  to_add    = desired_user_statements.reject { |grant| actual_user_statements.include?(grant) }
  idempotent = actual_user_statements - to_remove - to_add

  idempotent.each do |grant|
    puts "- Not touching #{grant}"
  end

  to_remove.each do |grant|
    puts "- Removing #{grant}"
    client.query(grant.revoke_sql)
  end

  to_add.each do |grant|
    puts "- Adding   #{grant}"
    client.query(grant.grant_sql)
  end
end

def generate_desired_user_grants(desired_state)
  desired_state.map do |desired_user|
    global_user_permissions = desired_user.global_permissions
    UserGrant.new(
      desired_user.user,
      desired_user.host,
      global_user_permissions["create"] ? "Y" : "N",
      global_user_permissions["drop"] ? "Y" : "N"
    )
  end
end

def fetch_user_statements(client)
  client.query("SELECT User, Host, Create_priv, Drop_priv, nixos_sha256 FROM user WHERE nixos_sha256 IS NOT NULL").map do |row|
    UserGrant.new(row["User"], row["Host"] , row["Create_priv"], row["Drop_priv"], row["nixos_sha256"])
  end
end

NIXOS_SHA_COLUMN="nixos_sha256"
# This method ensures that the NIXOS_SHA_COLUMN is added to the user and db tables.
def migrate_mysql_schema!(client)
  ["user", "db"].each do |table|
    result = client.query("DESCRIBE #{table}");
    nixos_user_data_column = result.find { |row| row["Field"] == NIXOS_SHA_COLUMN }

    if nixos_user_data_column.nil?
      puts "Adding '#{NIXOS_SHA_COLUMN}' column to '#{table}' table"
      client.query("ALTER TABLE #{table} ADD COLUMN #{NIXOS_SHA_COLUMN} CHAR(64)")
    end
  end
end


DEFAULT_CREDENTIALS = { username: "root", password: "", host: nil, socket: "/var/run/mysqld/mysqld.sock" }
def parse_credentials
  credentials = DEFAULT_CREDENTIALS.dup

  OptionParser.new do |opts|
    opts.banner = "Usage: nixos-mysql-permissions [options]. Provide the JSON schema on STDIN"

    opts.on("-u","--user-name", "MySQL user") do |username|
      credentials[:username] = username
    end

    opts.on("-p","--password", "MySQL password") do |password|
      credentials[:password] = password
    end

    opts.on("-h","--host", "MySQL host") do |host|
      credentials[:socket] = nil
      credentials[:host] = host
    end

    opts.on("-s","--socket", "MySQL host") do |socket|
      credentials[:socket] = socket
    end
  end

  credentials
end

def parse_input_to_desired_state(json)
  json.map do |name, entry|
    host = entry["host"]
    global_user_permissions = entry["user"]["privs"]
    DesiredUserState.new(name, host, global_user_permissions)
  end
end

class DesiredUserState < Struct.new(:user, :host, :global_permissions, :per_database_permissions)
end

class UserGrant
  attr_accessor :user, :host, :create_priv, :drop_priv, :expected_sha

  def initialize(user, host, create_priv, drop_priv, expected_sha=nil)
    self.user = user
    self.host = host
    self.create_priv = create_priv
    self.drop_priv = drop_priv
    self.expected_sha = expected_sha
  end

  def sha256
    if self.expected_sha
      self.expected_sha
    else
      sha = Digest::SHA256.new
      sha << self.user
      sha << self.host.to_s
      sha << self.create_priv
      sha << self.drop_priv

      sha.to_s
    end
  end

  def ==(other)
    other.sha256 == self.sha256
  end

  def revoke_sql
    'DELETE FROM user WHERE User = "%s" AND Host="%s" AND nixos_sha256="%s"' % (escaped_args [self.user, self.host, self.sha256])
  end

  def grant_sql
    'INSERT INTO user (User, Host, Create_priv, Drop_priv, nixos_sha256)' + \
    'VALUES ("%s", "%s", "%s", "%s", "%s")' % \
    (escaped_args [self.user, self.host, self.create_priv, self.drop_priv, self.sha256])
  end

  def to_s
    "'#{self.user}'@'#{self.host}' user permission (create=#{self.create_priv}, drop=#{self.drop_priv})"
  end

  private
  def escaped_args args
    args.map do |v|
      Mysql2::Client.escape(v.to_s)
    end
  end
end

main
