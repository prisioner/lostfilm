require 'yaml'

class ConfigLoader
  @@config_file_path = "#{__dir__}/../config.yml"

  attr_accessor :session, :db_path

  def initialize(reset_config: false)
    save_defaults! unless File.exists?(@@config_file_path)
    save_defaults! if reset_config

    content = File.read(@@config_file_path, encodint: 'utf-8')
    config = YAML.load(content)

    @db_path = config[:db_path]
    @session = config[:session]

    set_defaults!
  end

  def save!
    config = {
      session: @session,
      db_path: @db_path
    }.to_yaml

    file = File.new(@@config_file_path, 'w:UTF-8')
    file.puts config
    file.close
  end

  private

  # Если в файле отсутствовали нужные параметры - присваивает
  def set_defaults!
    @session ||= ""
    @db_path ||= File.absolute_path("#{__dir__}/../lostfilm.sqlite")
  end

  def save_defaults!
    set_defaults!
    save!
  end
end
