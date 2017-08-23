# encoding: utf-8
# Этот код необходим только при использовании русских букв на Windows
if Gem.win_platform?
  Encoding.default_external = Encoding.find(Encoding.locale_charmap)
  Encoding.default_internal = __ENCODING__

  [STDIN, STDOUT].each do |io|
    io.set_encoding(Encoding.default_external, Encoding.default_internal)
  end
end

require 'active_record'
require 'optparse'
require 'io/console'
require_relative 'lib/config_loader'
require_relative 'lib/progress'

# Загружаем конфиг
config = ConfigLoader.new

# Устанавливаем соединение с БД
conn = { adapter: 'sqlite3', database: config.db_path }
ActiveRecord::Base.establish_connection(conn)

# Подключаем модели
require_relative 'lib/lostfilm_client'

# Задаём опцию по умолчанию
options = {act: :get_new_episodes}

optparser = OptionParser.new do |opt|
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

  opt.on('-l [TYPE]', '--list [TYPE]', 'Выводит список сериалов',
                                       'all - всех',
                                       'fav - избранных',
                                       'followed (по умолчанию) - отслеживаемых') do |o|
    options[:act] = :show_list
    options[:type] = o.nil? ? :followed : o.to_sym
  end
end

# Если передан некорректный ключ - выводим справку
begin
  optparser.parse!
rescue OptionParser::InvalidOption
  puts "Параметры не распознаны"
  optparser.parse!(['-h'])
end

case options[:act]
##############
# Аторизация #
##############
when :login
  puts "Авторизация на сайте Lostfilm.tv"
  puts "Внимание: приложение НЕ хранит Ваш пароль"

  print "Введите ваш email: "
  email = STDIN.gets.chomp
  password = STDIN.getpass("Введите ваш пароль: ")

  begin
    config.session = LostFilmAPI.get_session(email: email, password: password)
  rescue LostFilmAPI::AuthorizationError
    # Сбрасываем старую сессию при неудачной авторизации
    # (если вдруг сессия была установлена)
    config.session = ''
    config.save!
    puts "Введён неверный логин или пароль."
    exit
  end

  puts "Авторизация прошла успешно!"

############################
# Загрузка списка сериалов #
############################
when :get_series_list, :get_new_episodes
  unless options[:act] == :get_new_episodes && !config.series_list_autoupdate
    lf = LostFilmAPI.new(session: config.session)
    fav_only = options[:type] == :fav

    puts "Загружаем список #{fav_only ? "избранных" : "всех"} сериалов"

    begin
      # Список сериалов, которые есть на сайте (с учетом опции)
      series_list = lf.get_series_list(favorited_only: fav_only)
    rescue LostFilmAPI::NotAuthorizedError
      puts "Необходимо пройти авторизацию! 'ruby lostfilm.rb --login'"
      exit
    end

    puts "Загрузка завершена"

    new_series_list = LostFilmClient.series_list_to_save(series_list, fav_only: fav_only)

    series_count = new_series_list.size

    if series_count > 0
      puts "Количество сериалов для сохранения: #{series_count}"
      pb = Progress.new(count: series_count, title: 'Сохранение объектов в БД')

      new_series_list.each { |series| series.save; pb.up }

      puts "Сохранение завершено."
    else
      puts "Нет новых элементов для сохранения"
    end
  end

################################################
# Изменяем статус "отслеживается" для сериалов #
################################################
when :follow, :unfollow
  puts LostFilmClient.change_follow_status(
    list: options[:list],
    act: options[:act],
    orig_titles: config.original_titles
  )
  exit

#########################
# Вывод списка сериалов #
#########################
when :show_list
  puts LostFilmClient.show_list(type: options[:type], orig_titles: config.original_titles)
  exit

#############################################################
# Неизвестные параметры, если сюда вообще возможно попасть? #
#############################################################
else
  puts "Команда не распознана. 'ruby lostfilm.rb --help' для вывода справки"
  exit
end

##############################################
# По умолчанию                               #
# Скачиваем торрент-файлы для новых эпизодов #
##############################################
begin
  res = LostFilmClient.get_new_episodes(config: config)
  puts res unless res.empty?
  puts "Скачивание завершено!"
rescue LostFilmAPI::NotAuthorizedError
  puts "Необходимо пройти авторизацию! 'ruby lostfilm.rb --login'"
  exit
end
