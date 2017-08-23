require_relative 'lostfilm_api'

module LostFilmClient
  module_function

  def series_list_to_save(series_list, fav_only:)
    # Список сериалов, которые уже есть в БД
    existed_series_list = Series.all.to_a
    # Список сериалов, которые надо сохранить в БД
    new_series_list =  series_list - existed_series_list
    # На случай, если у сериала сменился статус "в избранном" - проверяем
    # не был ли он раньше записан в БД
    new_series_list = check_matches(new_series_list, existed_series_list)
    # Если загружали только избранные - проверяем наличие сериалов, потерявших статус
    new_series_list += check_favorite_status(series_list, existed_series_list) if fav_only

    new_series_list
  end

  # Проверяем, не был ли элемент раньше записан в БД
  def check_matches(new_list, existed_list)
    new_list = new_list
    existed_list = existed_list

    new_list.map do |element|
      # Если ID элементов совпадает
      existed_element = existed_list.find { |e| e.lf_id == element.lf_id }
      # Если элемент найден - записываем новый статус favorited
      existed_element.favorited = element.favorited unless existed_element.nil?
      existed_element.nil? ? element : existed_element
    end
  end

  # Проверяем, что сериал был удален из избранных на сайте
  def check_favorite_status(list, existed_list)
    lost_favorite_status = existed_list.select do |series|
      series.favorited? &&
        !list.map(&:lf_id).include?(series.lf_id)
    end

    lost_favorite_status.each { |series| series.favorited = false }
  end

  def change_follow_status(list:, act:, orig_titles:)
    new_status = act == :follow
    res = []

    list.each do |id|
      series = Series.find_by(lf_id: id)
      if series
        series.update(followed: new_status)
        title = get_title(series, orig_titles: orig_titles)
        res << "Сериал '#{title}' #{series.followed? ? 'теперь' : 'больше не'} отслеживается"
      else
        res << "Сериал с ID=#{id} не найден в базе"
      end
    end

    res
  end

  def get_title(series, orig_titles: false)
    orig_titles ? series.title_orig : series.title
  end

  def show_list(type: :followed, orig_titles:)
    sort_field = orig_titles ? :title_orig : :title

    # Получаем список сериалов
    series_list =
      case type
      when :all
        Series.all
      when :fav
        Series.where(favorited: true)
      else
        Series.where(followed:true)
      end.order(sort_field => :asc).to_a

    width = get_width

    res = []
    res << separator(width)
    res << header(width)
    res << separator(width)
    series_list.each { |series| res << line(series, orig_titles, width) }
    res << separator(width)
  end

  def get_width
    # Привязываемся к ширине консоли для более корректного вывода таблицы
    width = STDOUT.winsize.last - 5
    width -= 1 if width.odd?
    # "Тянемся" между 60 и 100 символов. Меньше - не влезет, больше - плохо читается
    width = 60 if width < 60
    width = 100 if width > 100
    width
  end

  def separator(width)
    '-'*width
  end

  def header(width)
    spaces_width = (width - 54)/2

    '| ID  |' + ' '*spaces_width + 'Название сериала' +
      ' '*spaces_width + '| В избранном | Отслеживается |'
  end

  def line(series, orig_titles, width)
    id = series.lf_id.to_s
    title = get_title(series, orig_titles: orig_titles)
    favorited = series.favorited? ? '+' : ' '
    followed = series.followed? ? '+' : ' '

    buffer = title.length < (width - 40) ? ' '*(width - 40 - title.length) : ''

    '| ' + id + ' '*(4 - id.length) + '| ' + title[0..(width - 40 - 1)] + buffer +
      ' |' + ' '*6 + favorited + ' '*6 + '|' + ' '*7 + followed + ' '*7 + '|'
  end

  def update_episodes_list(config:)
    lf = LostFilmAPI.new(session: config.session)

    # Список отслеживаемых сериалов
    followed_series = Series.where(followed: true).to_a

    # Список их эпизодов, которые уже есть в БД
    exist_episodes_list = followed_series.flat_map(&:episodes).to_a

    pb = Progress.new(count: followed_series.size, title: "Получаем список новых эпизодов")

    # Для каждого сериала
    followed_series.each do |series|
      # Получаем список непросмотренных эпизодов
      episodes = lf.get_unwatched_episodes_list(series)
      # Находим из них список тех, которых нет в БД
      new_episodes_list = episodes - exist_episodes_list
      # И сохраняем
      new_episodes_list.each { |e| e.save }
      pb.up
    end
  end

  def get_new_episodes(config:)
    # Обновляем список эпизодов
    update_episodes_list(config: config)

    # Список отслеживаемых сериалов
    followed_series = Series.where(followed: true)
    # Список эпизодов отслеживаемых сериалов, которые ещё не были скачаны
    episodes_to_download = followed_series.flat_map(&:episodes).reject(&:downloaded)

    lf = LostFilmAPI.new(session: config.session)

    episodes_count = episodes_to_download.size
    err = []

    if episodes_count > 0
      ep_pb = Progress.new(count: episodes_count, title: 'Скачивание новых эпизодов')

      episodes_to_download.each do |episode|
        # Вернёт nil, либо количество байт, записанных в файл
        result = lf.download(
          episode.download_link,
          folder: config.download_folder,
          quality: config.quality_priority
        )

        # Проверяем, была ли запись в файл
        if result
          episode.update(downloaded: true)
        else
          series = episode.series
          title = get_title(series, orig_titles: config.original_titles)
          err << "Ошибка при скачивании эпизода #{episode.lf_id} сериала \"#{title}\""
        end

        ep_pb.up
      end
    else
      err << "Новых эпизодов не обнаружено"
    end

    err
  end
end
