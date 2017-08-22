class Episode < ActiveRecord::Base
  unless connection.data_source_exists? table_name
    connection.create_table table_name do |t|
      t.string :lf_id, null: false
      t.integer :series_id, null: false
      t.boolean :watched
      t.boolean :downloaded
      t.index [:lf_id], name: 'index_episodes_on_lf_id', unique: true
    end
  end

  belongs_to :series, primary_key: :lf_id, foreign_key: :series_id

  validates :lf_id, :series_id, presence: true
  validates :lf_id, uniqueness: true
  # 145-7-1
  validates :lf_id, format: /\A\d{1,3}-\d{1,2}-\d{1,3}\Z/

  before_validation :parse_series_id
  before_save :set_defaults_to_nil

  def download_link
    parts = lf_id.split('-')
    # /v_search.php?c=145&s=7&e=1
    "/v_search.php?c=#{parts[0]}&s=#{parts[1]}&e=#{parts[2]}"
  end

  def eql?(other)
    self.class == other.class && lf_id == other.lf_id
  end

  def hash
    lf_id.hash
  end

  private

  def parse_series_id
    unless series_id.present?
      self.series_id = lf_id.split('-').first.to_i if lf_id.present?
    end
  end

  def set_defaults_to_nil
    self.watched = false if watched.nil?
    self.downloaded = watched if downloaded.nil?
  end
end
