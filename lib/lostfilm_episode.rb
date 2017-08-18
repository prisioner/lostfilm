require_relative 'db_element'

class LostFilmEpisode < DBElement
  attr_reader :id, :series_id

  TABLE = "episodes"

  def initialize(id:, series_id: nil, watched: false, downloaded: nil, **args)
    super(**args)
    # string like '145-7-1'
    @id = id

    # first part of episode_id
    @series_id = series_id || @id.split('-').first.to_i

    @watched = watched

    @downloaded = downloaded
    @downloaded ||= @watched
  end

  def watched?
    @watched
  end

  def downloaded?
    @downloaded
  end

  def download_link
    parts = @id.split('-')
    # string like v_search.php?c=305&s=1&e=1
    "v_search.php?c=#{parts[0]}&s=#{parts[1]}&e=#{parts[2]}"
  end
end
