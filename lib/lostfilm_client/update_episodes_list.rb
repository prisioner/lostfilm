module LostFilmClient
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

  module_function :update_episodes_list
end
