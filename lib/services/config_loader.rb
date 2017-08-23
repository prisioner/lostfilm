require 'yaml'

class ConfigLoader
  DEFAULT_FILE_PATH = File.join(__dir__, '..', '..', 'config.yml')

  attr_accessor :session, :db_path, :download_folder, :original_titles
  attr_accessor :quality_priority, :series_list_autoupdate

  def initialize(file: DEFAULT_FILE_PATH, reset_config: false)
    @config_file = file

    # Записываем дефолтный конфиг файл, если он отсутствует
    save_defaults! unless File.exists?(@config_file)
    # Записываем дефолтный конфиг файл, если получена команда сброса настроек
    save_defaults! if reset_config

    content = File.read(@config_file, encodint: 'utf-8')
    config = YAML.load(content)

    # путь к БД
    @db_path = config[:db_path]
    # сессия lostfilm.tv
    @session = config[:session]
    # директория для загружаемых файлов
    @download_folder = config[:download_folder]
    # приоритет по качеству видеороликов
    @quality_priority = config[:quality_priority]
    # автоапдейт списка сериалов перед скачиванием
    @series_list_autoupdate = config[:series_list_autoupdate]
    # вывод оригинальных названий вместо российских
    @original_titles = config[:original_titles]

    # Устанавливаем значения по умолчанию для отсутствующих полей
    set_defaults!
  end

  # Пишем конфиг в файл
  def save!
    config = {
      session: @session,
      db_path: @db_path,
      download_folder: @download_folder,
      quality_priority: @quality_priority,
      series_list_autoupdate: @series_list_autoupdate,
      original_titles: @original_titles
    }.to_yaml

    file = File.new(@config_file, 'w:UTF-8')
    file.puts config
    file.close
  end

  private

  # Если в файле отсутствовали нужные параметры - присваивает
  def set_defaults!
    @session ||= ""
    @db_path ||= File.absolute_path(File.join(__dir__, '..', '..', 'lostfilm.sqlite'))
    @download_folder ||= File.absolute_path(File.join(__dir__, '..', '..', 'downloads'))
    @quality_priority ||= %w(1080 HD MP4 SD)
    @series_list_autoupdate = true if @series_list_autoupdate.nil?
    @original_titles = false if @original_titles.nil?
  end

  # Пишем дефолтный конфиг в файл
  def save_defaults!
    set_defaults!
    save!
  end
end
