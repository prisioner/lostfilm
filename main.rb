# encoding: utf-8

require_relative 'lib/lostfilm_client'
require 'optparse'

config = ConfigLoader.new
DBElement.prepare_db!(config.db_path)

options = {}

OptionParser.new do |opt|
  opt.banner = 'Использование: ruby lostfilm.rb [options]'

  opt.on('-h', '--help', 'Выводит эту справку') do
    puts opt
    exit
  end

  opt.on('-l', '--login', 'Запускает процесс авторизации') { options[:act] = :login }

  opt.on('--get-series-list [TYPE]', 'Загружает список сериалов (all(по умолчанию) - всех сериалов, fav - только избранных)') do |o|
    options[:act] = :get_series_list
    options[:type] = o.nil? ? :all : o.to_sym
  end

end.parse!

case options[:act]
# Аторизация
when :login
  begin
    config.session = LostFilmClient.auth
  rescue LostFilmAPI::AuthorizationError
    config.session = ''
    config.save!
    UserIO.puts_string "Введён неверный логин или пароль. " +
                         "Проверьте свои данные и попробуйте снова."
    exit
  end

# Загрузка списка сериалов
when :get_series_list
  begin
    LostFilmClient.get_series_list(type: options[:type], config: config)
  rescue LostFilmAPI::NotAuthorizedError
    UserIO.puts_string "Сперва необходимо пройти авторизацию! Используйте 'ruby lostfilm.rb --help' для вывода справки"
    exit
  end
else
  puts 'unknown protocol'
end

config.save!
