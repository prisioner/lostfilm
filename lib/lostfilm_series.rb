require_relative 'db_element'

class LostFilmSeries < DBElement
  attr_reader :id, :title, :title_orig, :link

  TABLE = "series"

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
end
