module LostFilmClient
  def get_series_list(type: :fav, config:)
    lf = LostFilmAPI.new(session: config.session)
    favorited_only = type == :fav

    puts "Загружаем список #{favorited_only ? "избранных" : "всех"} сериалов"

    # Список сериалов, которые есть на сайте (с учетом опции)
    series_list = lf.get_series_list(favorited_only: favorited_only)

    puts "Загрузка завершена"
    puts "Сохранение объектов в Базу Данных."

    # Список сериалов, которые уже есть в БД
    existed_series_list = LostFilmSeries.all
    # Список сериалов, которые надо сохранить в БД
    new_series_list =  series_list - existed_series_list
    # На случай, если у сериала сменился статус "в избранном" - проверяем
    # не был ли он раньше записан в БД
    new_series_list = check_matches(new_series_list, existed_series_list)
    # Если загружали только избранные - проверяем наличие сериалов, потерявших статус
    new_series_list += check_favorite_status(series_list, existed_series_list) if favorited_only

    new_series_list.each_with_index do |series, index|
      series.save!
      puts "Сохранено сериалов: #{index + 1} из #{new_series_list.size}" if (index + 1) % 10 == 0
    end

    puts "Сохранение завершено. Сохранено сериалов: #{new_series_list.size}"
  end

  module_function :get_series_list

  # Проверяем, не был ли элемент раньше записан в БД
  def check_matches(new_list, existed_list)
    new_list.map do |element|
      # Если ID элементов совпадает
      existed_element = existed_list.find { |e| e.id == element.id }
      # То элементу, который надо сохранить в БД под новым статусом
      # присваиваем соответствующий rowid
      element.rowid = existed_element.rowid unless existed_element.nil?
      element
    end
  end

  module_function :check_matches

  # Проверяем, что сериал был удален из избранных на сайте
  def check_favorite_status(list, existed_list)
    lost_favorite_status = existed_list.select do |series|
      series.favorited? &&
      !list.map(&:id).include?(series.id)
    end

    puts lost_favorite_status.map(&:title)
    exit
    lost_favorite_status.each { |series| series.favorited = false }
  end

  module_function :check_favorite_status
end
