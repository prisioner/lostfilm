require_relative 'db_element'

class LostFilmEpisode < DBElement
  attr_reader :id, :series_id
  attr_accessor :watched, :downloaded

  TABLE = "episodes"
  SQL_QUERY = <<~QUERY
              CREATE TABLE IF NOT EXISTS "main"."#{TABLE}" (
                "id" TEXT NOT NULL UNIQUE,
                "series_id" INTEGER,
                "watched" INTEGER,
                "downloaded" INTEGER
              )
              QUERY
  @@types[TABLE] = self

  def initialize(id:, series_id: nil, watched: false, downloaded: nil, **args)
    super(**args)
    # string like '145-7-1'
    @id = id

    # first part of episode_id
    @series_id = series_id || @id.split('-').first.to_i

    @watched = watched

    @downloaded = downloaded
    @downloaded = @watched if @downloaded.nil?
  end

  def watched?
    @watched
  end

  def downloaded?
    @downloaded
  end

  def download_link
    parts = @id.split('-')
    # /v_search.php?c=145&s=7&e=1
    "/v_search.php?c=#{parts[0]}&s=#{parts[1]}&e=#{parts[2]}"
  end

  private

  def self.from_db_hash(db_hash)
    new(
      rowid: db_hash['rowid'],
      id: db_hash['id'],
      series_id: db_hash['series_id'],
      watched: db_hash['watched'] == 1,
      downloaded: db_hash['downloaded'] == 1
    )
  end

  def to_db_hash
    {
      id: @id,
      series_id: @series_id,
      watched: watched? ? 1 : 0,
      downloaded: downloaded? ? 1 : 0
    }
  end

  def self.table
    TABLE
  end

  def table
    TABLE
  end
end
