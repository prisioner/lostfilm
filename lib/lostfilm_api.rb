require 'httparty'
require 'nokogiri'
require_relative 'series'
require_relative 'episode'

class LostFilmAPI
  AuthorizationError = Class.new(StandardError)
  NotAuthorizedError = Class.new(StandardError)

  include HTTParty
  base_uri 'lostfilm.tv'
  API_PATH = '/ajaxik.php'

  def self.get_session(email:, password:)
    options = auth_params(email, password)

    cookie = nil
    # защита от некорректного ответа (с пустым заголовком)
    3.times do
      res = post(API_PATH, options)
      # Неправильный логин/пароль - exception
      raise AuthorizationError if JSON.parse(res.body)['error']

      cookie = res.headers['set-cookie'].match(/lf_session=(?!deleted)[^;]+/i).to_s
      break unless cookie.nil?
    end

    cookie
  end

  def initialize(session: '')
    @session = session
  end

  def authorized?
    query = check_auth_params

    res = get_http_request(query: query)
    content = JSON.parse(res, symbolize_names: true)
    # ответ сервера для неавторизованного пользователя
    unauth_result = {error: 1}

    !content.eql?(unauth_result)
  end

  def get_series_list(favorited_only: true)
    # Для загрузки избранных сериалов необходима авторизация
    raise NotAuthorizedError if favorited_only && !authorized?

    # Параметры запроса
    query = series_params(favorited_only)

    series_list = []
    # крутимся, пока не получим пустой ответ
    loop do
      response = get_http_request(query: query)
      result = JSON.parse(response, symbolize_names: true)
      # Если получен пустой ответ - значит, сериалы кончились
      break if result[:data].empty?

      series_list += result[:data].map do |series|
        Series.new(
          lf_id: series[:id].to_i,
          title: series[:title],
          title_orig: series[:title_orig],
          link: series[:link],
          # series['favorited'] - true, если в избранном, nil - если нет, поэтому || false
          favorited: series[:favorited] || false
        )
      end

      # прибавляем "отступ"
      query[:o] += 10
    end

    series_list
  end

  # Загружает список эпизодов для определенного сериала
  def get_episodes_list(series, non_objects: false)
    path = "#{series.link}/seasons"
    response = get_http_request(path)

    # парсим вхождения вида 'data-code="145-7-1"' - ID эпизодов из элементов управления страницы
    episodes = response.scan(/data-code=\"(\d{1,3}-\d{1,2}-\d{1,2})\"/i).flatten

    # Если нужен просто список, а не объекты - возвращаем список
    return episodes if non_objects

    # Если нужны объекты - загружаем список просмотренных эпизодов
    watched_episodes = get_watched_episodes_list(series, non_objects: true)

    # формируем объекты
    episodes.map do |episode|
      Episode.new(
        lf_id: episode,
        series_id: series.lf_id,
        watched: watched_episodes.include?(episode)
      )
    end
  end

  # Загружает список просмотренных эпизодов
  def get_watched_episodes_list(series, non_objects: false)
    # требуется авторизация
    raise NotAuthorizedError unless authorized?

    # параметры запроса
    query = watched_episodes_params(series.lf_id)

    response = get_http_request(query: query)

    result = JSON.parse(response, symbolize_names: true)

    # в случае, если параметры запроса некорректны
    return [] if result.empty? || result[:error]

    # Если нужен просто список, а не объекты - возвращаем список
    return result[:data] if non_objects

    # формируем объекты
    result[:data].map do |ep|
      Episode.new(
        lf_id: ep,
        series_id: series.lf_id,
        watched: true,
        downloaded: true
      )
    end
  end

  # Возвращаем список непросмотренных эпизодов
  def get_unwatched_episodes_list(series, non_objects: false)
    # Список всех эпизодов
    list = get_episodes_list(series, non_objects: true)
    # Список просмотреннх эпизодов
    watched_list = get_watched_episodes_list(series, non_objects: true)
    # разница между ними - непросмотренные
    unwatched_list = list - watched_list

    # Если не нужны объекты, только список
    return unwatched_list if non_objects

    # Формируем объекты
    unwatched_list.map do |ep|
      Episode.new(
        lf_id: ep,
        series_id: series.lf_id,
        watched: false,
        downloaded: false
      )
    end
  end

  # Скачиваем файл
  def download(link, quality:, folder:)
    # Необходима авторизация
    raise NotAuthorizedError unless authorized?

    # Получаем ссылку на редирект
    new_link = get_redirect_link(link)

    # Получаем ссылку на торрент файл
    download_link = get_download_link(new_link, quality)

    # Если ничего не нашли - уходим
    # Мы можем ничего не найти в двух случаях
    # 1) Если установлены жесткие настройки по приоритету качества видео
    # 2) Если этот новый эпизод появился только что
    #    и сотрудники LostFilm ещё не успели загрузить сам файл
    return if download_link.nil?

    # Скачиваем файл
    file_content = get_http_request(download_link)
    # Парсим имя файла и строим путь
    file_name = get_file_name(file_content)
    file_path = File.join(folder, file_name)

    # Проверяем, что есть нужная нам директория
    Dir.mkdir(folder) unless Dir.exist?(folder)
    # Записываем файл на диск
    open(file_path, "wb") { |file| file.write(file_content) }
  end

  private

  def get_redirect_link(link)
    response = get_http_request(link)
    # редирект реализован через JS, поэтому парсим его из тела ответа
    response.match(/href=\"(?<link>[^\"]+)\"/i)['link'].to_s
  end

  def get_download_link(link, quality)
    response = get_http_request(link)
    doc = Nokogiri::HTML(response)
    # внутри лежат "метки" - SD, HD, 1080, MP4
    labels = doc.search("//div[@class='inner-box--label']")
    # список доступных вариантов
    allowed_qualities = labels.map(&:text).map(&:strip)
    # ищем самый приоритетный наш вариант, который есть среди доступных
    selected_quality = quality.find { |q| allowed_qualities.include?(q) }
    # Если настройки приоритета качества слишком жесткие - уходим
    return if selected_quality.nil?
    # Определяем нужный нам div
    label = labels.find { |label| label.text.include?(selected_quality) }
    # Ищем первую ссылку в его родительском div - она-то нам и нужна
    box = label.parent
    box.search("a").first.attributes['href'].value
  end

  def get_file_name(body)
    # ищем что-то типа такого "name43:This.is.us.S01E15.1080p.rus.LostFilm.TV.mkv12:"
    # и вытаскиваем оттуда имя - "This.is.us.S01E15.1080p.rus.LostFilm.TV.mkv"
    name = body.match(/name[^:]*:(?<file_name>[^:]+?)\d+:/i)['file_name'].to_s
    "#{name}.torrent"
  end

  def get_http_request(path = API_PATH, query: {})
    options = { query: query, headers: { cookie: @session } }
    response = self.class.get(path, options)
    response.body
  end

  def self.auth_params(email, password)
    { body: { act: 'users', type: 'login', mail: email, pass: password, rem: 1 } }
  end

  def check_auth_params
    watched_episodes_params(1)
  end

  def series_params(fav_only)
    tab = fav_only ? 99 : 0
    { act: 'serial', type: 'search', o: 0, s: 2, t: tab }
  end

  def watched_episodes_params(lf_id)
    { act: 'serial', type: 'getmarks', id: lf_id }
  end
end
