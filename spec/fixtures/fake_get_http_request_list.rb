class LostFilmAPI
  def get_http_request(url = nil, query: {})
    response1 = File.read("#{__dir__}/get_series_list_1.txt")
    response2 = File.read("#{__dir__}/get_series_list_2.txt")

    if query[:o] == 0
      response1
    else
      response2
    end
  end
end
