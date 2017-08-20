module LostFilmClient
  def show_list(type: :followed, original_titles:)
    series_list =
      case type
      when :all
        LostFilmSeries.all
      when :fav
        LostFilmSeries.where(favorited: true)
      else
        LostFilmSeries.where(followed:true)
      end

    if original_titles
      series_list.sort_by! { |series| series.title_orig }
    else
      series_list.sort_by! { |series| series.title }
    end

    width = STDOUT.winsize.last - 5
    width -= 1 if width.odd?
    width = 60 if width < 60
    width = 100 if width > 100

    print_separator(width)
    print_header(width)
    print_separator(width)
    series_list.each { |series| print_line(series, original_titles, width) }
    print_separator(width)
  end

  module_function :show_list

  def print_separator(width)
    puts '-'*width
  end

  module_function :print_separator

  def print_header(width)
    print '| ID  |'
    print ' '*((width - 54)/2)
    print 'Название сериала'
    print ' '*((width - 54)/2)
    print '|'
    print ' В избранном '
    print '|'
    print ' Отслеживается '
    puts '|'
  end

  module_function :print_header

  def print_line(series, original_titles, width)
    id = series.id.to_s
    title = original_titles ? series.title_orig : series.title
    favorited = series.favorited? ? '+' : ' '
    followed = series.followed? ? '+' : ' '

    print '| '
    print id
    print ' '*(4 - id.length)
    print '| '
    print title[0..(width - 40 - 1)]
    print ' '*(width - 40 - title.length) if title.length < (width - 40)
    print ' |'
    print ' '*6
    print favorited
    print ' '*6
    print '|'
    print ' '*7
    print followed
    print ' '*7
    puts '|'
  end

  module_function :print_line
end
