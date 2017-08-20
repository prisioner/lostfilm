module LostFilmClient
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

  module_function :get_new_episodes
end
