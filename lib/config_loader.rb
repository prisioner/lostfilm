require 'yaml'

class ConfigLoader
  CONFIG_FILE_PATH = File.join(__dir__, '..', 'config.yml')

  attr_accessor :session, :db_path, :download_folder
  attr_accessor :quality_priority, :series_list_autoupdate

  def initialize(reset_config: false)
    save_defaults! unless File.exists?(CONFIG_FILE_PATH)
    save_defaults! if reset_config

    content = File.read(CONFIG_FILE_PATH, encodint: 'utf-8')
    config = YAML.load(content)

    @db_path = config[:db_path]
    @session = config[:session]
    @download_folder = config[:download_folder]
    @quality_priority = config[:quality_priority]
    @series_list_autoupdate = config[:series_list_autoupdate]

    set_defaults!
  end

  def save!
    config = {
      session: @session,
      db_path: @db_path,
      download_folder: @download_folder,
      quality_priority: @quality_priority,
      series_list_autoupdate: @series_list_autoupdate
    }.to_yaml

    file = File.new(CONFIG_FILE_PATH, 'w:UTF-8')
    file.puts config
    file.close
  end

  private

  # Если в файле отсутствовали нужные параметры - присваивает
  def set_defaults!
    @session ||= ""
    @db_path ||= File.absolute_path(File.join(__dir__, '..', 'lostfilm.sqlite'))
    @download_folder ||= File.absolute_path(File.join(__dir__, '..', 'downloads'))
    @quality_priority ||= %w(1080 MP4 SD)
    @series_list_autoupdate ||= true
  end

  def save_defaults!
    set_defaults!
    save!
  end
end
