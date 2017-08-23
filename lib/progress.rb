require 'ruby-progressbar'

class Progress
  def initialize(count:, title: 'Прогресс: ')
    @bar = ProgressBar.create
    @bar.total = count
    @bar.title = title
    @bar.progress_mark = '*'
    @bar.remainder_mark = '.'
  end

  def up
    @bar.increment
  end
end
