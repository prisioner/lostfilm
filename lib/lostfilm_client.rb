require 'io/console'
require_relative 'lostfilm_api'
require_relative 'config_loader'

module LostFilmClient
  module_function

  def auth
    puts "Авторизация на сайте Lostfilm.tv"
    puts "Внимание: приложение НЕ хранит Ваш пароль"

    print "Введите ваш email: "
    email = STDIN.gets.chomp
    password = STDIN.getpass("Введите ваш пароль: ")
    session = LostFilmAPI.get_session(email: email, password: password)

    puts "Авторизация прошла успешно!"
    session
  end

  def get_series_list(type: :fav, config:)
    lf = LostFilmAPI.new(session: config.session)
    favorited_only = type == :fav

    puts "Загружаем список #{favorited_only ? "избранных" : "всех"} сериалов"

    series_list = lf.get_series_list(favorited_only: favorited_only)

    puts "Загрузка завершена"
    puts "Сохранение объектов в Базу Данных. Это может занять несколько минут."

    existed_series_list = LostFilmSeries.all
    new_series_list =  series_list - existed_series_list
    new_series_list = check_matches(new_series_list, existed_series_list)

    new_series_list.each_with_index do |series, index|
      series.save!
      puts "Сохранено сериалов: #{index + 1} из #{new_series_list.size}" if (index + 1) % 10 == 0
    end

    puts "Сохранение завершено. Сохранено сериалов: #{new_series_list.size}"
  end

  def change_follow_status(list:, act:)
    new_status = act == :follow

    list.each do |id|
      series = LostFilmSeries.find_by(id: id)
      if series
        series.followed = new_status
        series.save!
        puts "Сериал '#{series.title}' #{series.followed? ? 'теперь' : 'больше не'} отслеживается"
      else
        puts "Сериал с ID=#{id} не найден в базе"
      end
    end
  end

  def get_new_episodes(config:)
    get_series_list(config: config) if config.series_list_autoupdate
    update_episodes_list(config: config)

    followed_series = LostFilmSeries.where(followed: true)
    # Список эпизодов отслеживаемых сериалов, которые ещё не были скачаны
    episodes_to_download = followed_series.flat_map(&:episodes).reject(&:downloaded)

    puts "Обнаружено новых эпизодов: #{episodes_to_download.size}"

    lf = LostFilmAPI.new(session: config.session)
    episodes_to_download.each_with_index do |episode, index|
      result = lf.download(
        episode.download_link,
        folder: config.download_folder,
        quality: config.quality_priority
      )

      if result
        episode.downloaded = true
        episode.save!
      else
        series = LostFilmSeries.find_by(id: episode.series_id)
        puts "Ошибка при скачивании эпизода #{episode.id} сериала \"#{series.title}\""
      end

      puts "Обработано: #{index + 1} из #{episodes_to_download.size}" if (index + 1) % 10 == 0
    end
    puts "Скачивание завершено! Сохраненные файлы в папке: #{config.download_folder}"
  end

  def update_episodes_list(config:)
    puts "Обновляем список эпизодов"
    lf = LostFilmAPI.new(session: config.session)

    followed_series = LostFilmSeries.where(followed: true)
    exist_episodes_list = followed_series.flat_map(&:episodes)

    followed_series.each_with_index do |series, index|
      episodes = lf.get_unwatched_episodes_list(series)
      new_episodes_list = episodes - exist_episodes_list
      new_episodes_list.each { |e| e.save! }

      puts "Обработано отслеживаемых сериалов: #{index + 1} из #{followed_series.size}" if (index + 1) % 10 == 0
    end

    puts "Обновление списка эпизодов завершено"
  end

  def check_matches(new_list, existed_list)
    new_list.map do |element|
      existed_element = existed_list.find { |e| e.id == element.id }
      element.rowid = existed_element.rowid unless existed_element.nil?
      element
    end
  end
end
