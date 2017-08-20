class LostFilmAPI
  def get_http_request(url, params: {})
    response1 = File.read("#{__dir__}/get_series_list_1.txt")
    response2 = File.read("#{__dir__}/get_series_list_2.txt")

    if params[:o] == 0
      response1
    else
      response2
    end
  end
end
