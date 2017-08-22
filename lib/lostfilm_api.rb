require 'net/http'
require 'nokogiri'
require 'json'
require_relative 'series'
require_relative 'episode'

class LostFilmAPI
  AuthorizationError = Class.new(StandardError)
  NotAuthorizedError = Class.new(StandardError)

  LF_URL = "https://www.lostfilm.tv"
  LF_API_URL = "#{LF_URL}/ajaxik.php"

  attr_reader :session
  
  def self.get_session(email:, password:)
    # параметры запроса для авторизации
    params = {
      act: 'users',
      type: 'login',
      mail: email,
      pass: password,
      rem: 1
    }
    uri = URI(LF_API_URL)

    cookie = nil
    # прикрываемся от некорректного ответа - повторяем, если пришла пустая сессия
    3.times do
      res = Net::HTTP.post_form(uri, params)

      # Если введён неверный логин или пароль
      raise AuthorizationError if JSON.parse(res.body)['error']

      cookie = res['set-cookie'].match(/lf_session=(?!deleted)[^;]+/i).to_s
      break unless cookie.empty?
    end

    cookie
  end

  def initialize(session:)
    @session = session
  end

  # проверка, активна ли сессия
  def authorized?
    # Пытаемся получить список просмотренных эпизодов для какого-то сериала
    params = {
      act: 'serial',
      type: 'getmarks',
      id: '1'
    }

    response = get_http_request(LF_API_URL, params: params)
    content = JSON.parse(response)

    # Ответ сервера, если мы не авторизованы
    unauth_result = {'error' => 1}

    !content.eql?(unauth_result)
  end

  # Загружаем список сериалов
  def get_series_list(favorited_only: true)
    # Для загрузки избранных сериалов необходима авторизация
    raise NotAuthorizedError if favorited_only && !authorized?

    # Параметры запроса
    params = {
      act: 'serial',
      type: 'search',
      # "отступ", выдача от API по 10 штук за запрос
      o: 0,
      # сортировка. 1 - по рейтингу, 2 - по алфавиту, 3 - по новизне
      s: 2,
      # вкладки. 99 - избранные, 0 - все, 1 - новые, 2 - снимающиеся, 5 - завершенные
      t: favorited_only ? 99 : 0
    }

    series_list = []
    # крутимся, пока не получим пустой ответ
    loop do
      response = get_http_request(LF_API_URL, params: params)
      result = JSON.parse(response)
      # Если получен пустой ответ - значит, сериалы кончились
      break if result['data'].empty?

      series_list += result['data'].map do |series|
        Series.new(
          lf_id: series['id'].to_i,
          title: series['title'],
          title_orig: series['title_orig'],
          link: series['link'],
          # series['favorited'] - true, если в избранном, nil - если нет, поэтому || false
          favorited: series['favorited'] || false
        )
      end

      # прибавляем "отступ"
      params[:o] += 10
    end

    series_list
  end

  # Загружает список эпизодов для определенного сериала
  def get_episodes_list(series, non_objects: false)
    url = "#{LF_URL}#{series.link}/seasons"
    response = get_http_request(url)

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
    params = {
      act: 'serial',
      type: 'getmarks',
      id: series.lf_id
    }

    response = get_http_request(LF_API_URL, params: params)

    result = JSON.parse(response)

    # в случае, если параметры запроса некорректны
    return [] if result.empty? || result['error']

    # Если нужен просто список, а не объекты - возвращаем список
    return result['data'] if non_objects

    # формируем объекты
    result['data'].map do |ep|
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
    response = get_http_request("#{LF_URL}#{link}")
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

  # GET запрос с параметрами и заголовком Cookie, возвращает тело ответа
  def get_http_request(url, params: {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?

    req = Net::HTTP::Get.new(uri)
    req['cookie'] = @session

    res = Net::HTTP.start(uri.hostname, 80) { |http| http.request(req) }

    res.body
  end
end
