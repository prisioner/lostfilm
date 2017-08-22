module LostFilmClient
  def change_follow_status(list:, act:, original_titles:)
    new_status = act == :follow

    list.each do |id|
      series = Series.find_by(lf_id: id)
      if series
        series.followed = new_status
        series.save!
        title = original_titles ? series.title_orig : series.title
        puts "Сериал '#{title}' #{series.followed? ? 'теперь' : 'больше не'} отслеживается"
      else
        puts "Сериал с ID=#{id} не найден в базе"
      end
    end
  end

  module_function :change_follow_status
end
