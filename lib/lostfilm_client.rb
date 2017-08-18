require_relative 'user_io'
require_relative 'lostfilm_api'
require_relative 'config_loader'

module LostFilmClient
  module_function

  def auth
    UserIO.puts_string "Авторизация на сайте Lostfilm.tv"
    UserIO.puts_string "Внимание: приложение НЕ хранит Ваш пароль"

    email = UserIO.get_input("Введите ваш email: ")
    password = UserIO.get_pass("Введите ваш пароль: ")
    session = LostFilmAPI.get_session(email: email, password: password)

    UserIO.puts_string "Авторизация прошла успешно!"
    session
  end

  def get_series_list(type: :fav, config:)
    lf = LostFilmAPI.new(session: config.session)
    favorited_only = type == :fav

    UserIO.print_string "Загружаем список "
    UserIO.puts_string "#{favorited_only ? "избранных" : "всех"} сериалов"

    series_list = lf.get_series_list(favorited_only: favorited_only)

    UserIO.puts_string "Загрузка завершена"
    UserIO.print_string "Сохранение объектов в Базу Данных."
    UserIO.puts_string " Это может занять несколько минут."

    existed_series_list = LostFilmSeries.all
    new_series_list =  series_list - existed_series_list
    new_series_list = check_matches(new_series_list, existed_series_list)

    new_series_list.each_with_index do |series, index|
      series.save!
      UserIO.puts_string(
        "Сохранено сериалов: #{index + 1} из #{new_series_list.size}"
      ) if (index + 1) % 10 == 0
    end

    UserIO.print_string "Сохранение завершено."
    UserIO.puts_string " Сохранено сериалов: #{new_series_list.size}"
  end

  def change_follow_status(list:, act:)
    new_status = act == :follow

    list.each do |id|
      series = LostFilmSeries.find_by(id: id)
      if series
        series.followed = new_status
        series.save!
        UserIO.print_string "Сериал \"#{series.title}\" "
        UserIO.puts_string "#{series.followed? ? "теперь" : "больше не"} отслеживается"
      else
        UserIO.puts_string "Сериал с ID=#{id} не найден в базе"
      end
    end
  end

  def check_matches(new_list, existed_list)
    new_list.map do |element|
      existed_element = existed_list.find { |e| e.id == element.id }
      element.rowid = existed_element.rowid unless existed_element.nil?
      element
    end
  end
end
