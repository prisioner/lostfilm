module LostFilmClient
  def get_new_episodes(config:)
    # Обновляем список сериалов
    get_series_list(config: config) if config.series_list_autoupdate
    # Обновляем список эпизодов
    update_episodes_list(config: config)

    # Список отслеживаемых сериалов
    followed_series = Series.where(followed: true)
    # Список эпизодов отслеживаемых сериалов, которые ещё не были скачаны
    episodes_to_download = followed_series.flat_map(&:episodes).reject(&:downloaded)

    puts "Обнаружено новых эпизодов: #{episodes_to_download.size}"

    lf = LostFilmAPI.new(session: config.session)
    episodes_to_download.each_with_index do |episode, index|
      # Вернёт nil, либо количество байт, записанных в файл
      result = lf.download(
        episode.download_link,
        folder: config.download_folder,
        quality: config.quality_priority
      )

      # Проверяем, была ли запись в файл
      if result
        episode.downloaded = true
        episode.save
      else
        series = Series.find_by(lf_id: episode.series_id)
        puts "Ошибка при скачивании эпизода #{episode.lf_id} сериала \"#{series.title}\""
      end

      puts "Обработано: #{index + 1} из #{episodes_to_download.size}" if (index + 1) % 10 == 0
    end
    puts "Скачивание завершено! Сохраненные файлы в папке: #{config.download_folder}"
  end

  module_function :get_new_episodes
end
