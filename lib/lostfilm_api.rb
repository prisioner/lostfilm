require 'net/http'
require 'nokogiri'
require 'json'
require_relative 'lostfilm_series'
require_relative 'lostfilm_episode'

class LostFilmAPI
  AuthorizationError = Class.new(StandardError)
  NotAuthorizedError = Class.new(StandardError)

  LF_URL = "https://www.lostfilm.tv"
  LF_API_URL = "#{LF_URL}/ajaxik.php"

  attr_reader :session

  def self.get_session(email:, password:)
    params = {
      act: 'users',
      type: 'login',
      mail: email,
      pass: password,
      rem: 1
    }
    uri = URI(LF_API_URL)

    cookie = nil
    # try several times to prevent invalid answer issues
    3.times do
      res = Net::HTTP.post_form(uri, params)

      raise AuthorizationError if JSON.parse(res.body)['error']

      cookie = res['set-cookie'].match(/lf_session=(?!deleted)[^;]+/i).to_s
      break unless cookie.empty?
    end

    cookie
  end

  def initialize(session:)
    @session = session
  end

  def authorized?
    params = {
      act: 'serial',
      type: 'getmarks',
      id: '1'
    }

    response = get_http_request(LF_API_URL, params: params)
    content = JSON.parse(response)

    unauth_result = {'error' => 1}

    !content.eql?(unauth_result)
  end

  def get_series_list(favorited_only: true)
    raise NotAuthorizedError if favorited_only && !authorized?

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
    loop do
      response = get_http_request(LF_API_URL, params: params)
      result = JSON.parse(response)
      # Если получен пустой ответ - значит, сериалы кончились
      break if result['data'].empty?

      series_list += result['data'].map do |series|
        LostFilmSeries.new(
          id: series['id'].to_i,
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

  def get_episodes_list(series, non_objects: false)
    url = "#{LF_URL}#{series.link}/seasons"
    response = get_http_request(url)

    episodes = response.scan(/data-code=\"(\d{1,3}-\d{1,2}-\d{1,2})\"/i).flatten

    return episodes if non_objects

    watched_episodes = get_watched_episodes_list(series, non_objects: true)

    episodes.map do |episode|
      LostFilmEpisode.new(
        id: episode,
        series_id: series.id,
        watched: watched_episodes.include?(episode)
      )
    end
  end

  def get_watched_episodes_list(series, non_objects: false)
    raise NotAuthorizedError unless authorized?

    params = {
      act: 'serial',
      type: 'getmarks',
      id: series.id
    }

    response = get_http_request(LF_API_URL, params: params)

    result = JSON.parse(response)

    # в случае, если пытаемся обратиться к сериалу, которого не существует
    return [] if result.empty? || result['error']
    return result['data'] if non_objects

    result['data'].map do |ep|
      LostFilmEpisode.new(
        id: ep,
        series_id: series.id,
        watched: true,
        downloaded: true
      )
    end
  end

  def get_unwatched_episodes_list(series, non_objects: false)
    list = get_episodes_list(series, non_objects: true)
    watched_list = get_watched_episodes_list(series, non_objects: true)
    unwatched_list = list - watched_list

    return unwatched_list if non_objects

    unwatched_list.map do |ep|
      LostFilmEpisode.new(
        id: ep,
        series_id: series.id,
        watched: false,
        downloaded: false
      )
    end
  end

  def download(link, quality:, folder:)
    raise NotAuthorizedError unless authorized?

    new_link = get_redirect_link(link)

    download_link = get_download_link(new_link, quality)
    return if download_link.nil?

    file_content = get_http_request(download_link)
    file_name = get_file_name(file_content)
    file_path = File.join(folder, file_name)

    Dir.mkdir(folder) unless Dir.exist?(folder)
    open(file_path, "wb") { |file| file.write(file_content) }
  end

  private

  def get_redirect_link(link)
    response = get_http_request("#{LF_URL}#{link}")
    response.match(/href=\"(?<link>[^\"]+)\"/i)['link'].to_s
  end

  def get_download_link(link, quality)
    response = get_http_request(link)
    doc = Nokogiri::HTML(response)
    labels = doc.search("//div[@class='inner-box--label']")
    allowed_qualities = labels.map(&:text).map(&:strip)
    selected_quality = quality.find { |q| allowed_qualities.include?(q) }
    return if selected_quality.nil?
    label = labels.find { |label| label.text.include?(selected_quality) }
    box = label.parent
    box.search("a").first.attributes['href'].value
  end

  def get_file_name(body)
    # ищем что-то типа такого "name43:This.is.us.S01E15.1080p.rus.LostFilm.TV.mkv12:"
    # и вытаскиваем оттуда имя - "This.is.us.S01E15.1080p.rus.LostFilm.TV.mkv"
    name = body.match(/name[^:]*:(?<file_name>[^:]+?)\d+:/i)['file_name'].to_s
    "#{name}.torrent"
  end

  def get_http_request(url, params: {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?

    req = Net::HTTP::Get.new(uri)
    req['cookie'] = @session

    res = Net::HTTP.start(uri.hostname, 80) { |http| http.request(req) }

    res.body
  end
end
