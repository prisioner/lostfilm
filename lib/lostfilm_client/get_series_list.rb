module LostFilmClient
  def get_series_list(type: :fav, config:)
    lf = LostFilmAPI.new(session: config.session)
    favorited_only = type == :fav

    puts "Загружаем список #{favorited_only ? "избранных" : "всех"} сериалов"

    series_list = lf.get_series_list(favorited_only: favorited_only)

    puts "Загрузка завершена"
    puts "Сохранение объектов в Базу Данных. Это может занять несколько минут."

    existed_series_list = LostFilmSeries.all
    new_series_list =  series_list - existed_series_list
    new_series_list = self::check_matches(new_series_list, existed_series_list)

    new_series_list.each_with_index do |series, index|
      series.save!
      puts "Сохранено сериалов: #{index + 1} из #{new_series_list.size}" if (index + 1) % 10 == 0
    end

    puts "Сохранение завершено. Сохранено сериалов: #{new_series_list.size}"
  end

  module_function :get_series_list

  def check_matches(new_list, existed_list)
    new_list.map do |element|
      existed_element = existed_list.find { |e| e.id == element.id }
      element.rowid = existed_element.rowid unless existed_element.nil?
      element
    end
  end

  module_function :check_matches
end
