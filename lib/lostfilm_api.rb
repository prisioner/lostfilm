require 'net/http'
require 'json'
require_relative 'lostfilm_series'
require_relative 'lostfilm_episode'

class LostFilmAPI
  class AuthorizationError < StandardError
  end

  class NotAuthorizedError < StandardError
  end

  LF_URL = "https://www.lostfilm.tv"
  LF_API_URL = "#{LF_URL}/ajaxik.php"

  attr_reader :cookie

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

  def initialize(cookie:)
    @cookie = cookie
  end

  def authorized?
    params = {
      act: 'serial',
      type: 'getmarks',
      id: '1'
    }

    response = get_http_request(LF_API_URL, params)
    content = JSON.parse(response)

    unauth_result = {'error' => 1}

    !content.eql?(unauth_result)
  end

  def get_series_list

  end

  def get_episodes_list

  end

  def get_watched_episodes_list

  end

  def get_unwatched_episodes_list

  end

  private

  def get_http_request(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?

    req = Net::HTTP::Get.new(uri)
    req['cookie'] = @cookie

    res = Net::HTTP.start(uri.hostname, 80) { |http| http.request(req) }

    res.body
  end
end
