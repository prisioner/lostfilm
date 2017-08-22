class Series < ActiveRecord::Base
  unless connection.data_source_exists? table_name
    connection.create_table table_name do |t|
      t.integer :lf_id, null: false
      t.string :title, null: false
      t.string :title_orig
      t.string :link
      t.boolean :favorited
      t.boolean :followed
      t.index [:lf_id], name: 'index_series_on_lf_id', unique: true
    end
  end

  has_many :episodes, primary_key: :lf_id, foreign_key: :series_id, dependent: :destroy

  validates :lf_id, :title, :link, presence: true
  validates :lf_id, uniqueness: true
  validates :lf_id, format: /\A\d{1,3}\Z/

  before_save :set_defaults_to_nil

  def eql?(other)
    self.class == other.class && self.lf_id == other.lf_id && self.favorited == other.favorited
  end

  def hash
    lf_id.hash
  end

  private

  def set_defaults_to_nil
    self.favorited = false if favorited.nil?
    self.followed = favorited if followed.nil?
  end
end
