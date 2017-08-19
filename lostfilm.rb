# encoding: utf-8

require_relative 'lib/lostfilm_client'
require 'optparse'

config = ConfigLoader.new
DBElement.prepare_db!(config.db_path)

options = {act: :get_new_episodes}

OptionParser.new do |opt|
  opt.banner = 'Использование: ruby lostfilm.rb [options]'

  opt.on('-h', '--help', 'Выводит эту справку') do
    puts opt
    exit
  end

  opt.on('--login', 'Запускает процесс авторизации') { options[:act] = :login }

  opt.on('-s [TYPE]', '--get-series-list [TYPE]', 'Загружает список сериалов',
                                                  'all (по умолчанию) - всех сериалов',
                                                  'fav - только избранных') do |o|
    options[:act] = :get_series_list
    options[:type] = o.nil? ? :all : o.to_sym
  end

  opt.on('-f ID,ID,ID', '--follow ID,ID,ID', Array,
         'Добавляет сериал(ы) в список отслеживаемых') do |o|
    options[:act] = :follow
    options[:list] = o.map(&:to_i)
  end

  opt.on('-u ID,ID,ID', '--unfollow ID,ID,ID', Array,
         'Убирает сериал(ы) из списка отслеживаемых') do |o|
    options[:act] = :unfollow
    options[:list] = o.map(&:to_i)
  end

  opt.on('-e', '--get-new-episodes',
         'Загружает список новых эпизодов (действие по умолчанию)') do
    options[:act] = :get_new_episodes
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
    UserIO.puts_string "Необходимо пройти авторизацию! Используйте 'ruby lostfilm.rb --help' для вывода справки"
    exit
  end

# Изменяем статус "отслеживается" для сериалов
when :follow, :unfollow
  LostFilmClient.change_follow_status(options)

# Скачиваем торрент-файлы для новых эпизодов
when :get_new_episodes
  LostFilmClient.get_new_episodes(config: config)
else
  UserIO.puts_string "Ваша команда не распознана. Используйте 'ruby lostfilm.rb --help' для вывода справки"
end

config.save!
