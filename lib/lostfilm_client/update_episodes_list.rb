module LostFilmClient
  def update_episodes_list(config:)
    puts "Обновляем список эпизодов"
    lf = LostFilmAPI.new(session: config.session)

    # Список отслеживаемых сериалов
    followed_series = Series.where(followed: true)
    # Список их эпизодов, которые уже есть в БД
    exist_episodes_list = followed_series.flat_map(&:episodes).to_a

    # Для каждого сериала
    followed_series.each_with_index do |series, index|
      # Получаем список непросмотренных эпизодов
      episodes = lf.get_unwatched_episodes_list(series)
      # Находим из них список тех, которых нет в БД
      new_episodes_list = episodes - exist_episodes_list
      # И сохраняем
      new_episodes_list.each { |e| e.save }
      puts "Обработано отслеживаемых сериалов: #{index + 1} из #{followed_series.size}" if (index + 1) % 10 == 0
    end

    puts "Обновление списка эпизодов завершено"
  end

  module_function :update_episodes_list
end
