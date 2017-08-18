require_relative 'db_element'

class LostFilmSeries < DBElement
  attr_reader :id, :title, :title_orig, :link

  TABLE = "series"
  @@types[TABLE] = self

  def self.from_db_hash(db_hash)
    new(
      rowid: db_hash['rowid'],
      id: db_hash['id'],
      title: db_hash['title'],
      title_orig: db_hash['title_orig'],
      link: db_hash['link'],
      favorited: db_hash['favorited'] == 1,
      followed: db_hash['followed'] == 1,
      episodes: LostFilmEpisode.where(series_id: db_hash['id'])
    )
  end

  def initialize(id:, title:, title_orig:, link:, favorited: false, followed: nil, episodes: [], **args)
    super(**args)
    @id = id
    @title = title
    @title_orig = title_orig
    @link = link
    @favorited = favorited

    @followed = followed
    @followed ||= @favorited

    @episodes = episodes
  end

  def favorited?
    @favorited
  end

  def followed?
    @followed
  end

  def eql?(other)
    super(other) &&
      @favorited.eql?(other.favorited?)
  end

  private

  def to_db_hash
    {
      id: @id,
      title: @title,
      title_orig: @title_orig,
      link: @link,
      favorited: favorited? ? 1 : 0,
      followed: followed? ? 1 : 0
    }
  end

  def self.table
    TABLE
  end

  def table
    TABLE
  end
end
