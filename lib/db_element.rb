require 'sqlite3'

class DBElement
  attr_accessor :rowid

  # Необходимо переопределить
  TABLE = nil

  # Типы элементов
  @@types = {}

  # Сохраняет путь к БД в переменную класса
  # Готовит БД к работе - создаёт отсутствующие таблицы
  def self.prepare_db!(db_path)
    ## Сохраняем путь к БД
    @@db_path = db_path
    # Коннектимся
    db = SQLite3::Database.open(@@db_path)
    # Создаём таблицу для сериалов, если её нет в БД
    db.execute(
      <<~SERIES_TABLE
        CREATE TABLE IF NOT EXISTS "main"."series" (
          "id" INTEGER NOT NULL UNIQUE,
          "title" TEXT,
          "title_orig" TEXT,
          "link" TEXT,
          "favorited" INTEGER,
          "followed" INTEGER
        )
      SERIES_TABLE
    )
    # Создаём таблицу для эпизодов, если её нет в БД
    db.execute(
      <<~EPISODES_TABLE
        CREATE TABLE IF NOT EXISTS "main"."episodes" (
          "id" TEXT NOT NULL UNIQUE,
          "series_id" INTEGER,
          "watched" INTEGER,
          "downloaded" INTEGER
        )
      EPISODES_TABLE
    )
    # Отключаемся
    db.close
  end

  def self.all
    db = SQLite3::Database.open(@@db_path)
    db.results_as_hash = true

    list = db.execute("SELECT rowid, * FROM #{table}")
    db.close

    list.map { |e| @@types[table].from_db_hash(e) }
  end

  def self.where(params)
    db = SQLite3::Database.open(@@db_path)
    db.results_as_hash = true

    # Заглушка, т.к. SQLite не поддерживает Boolean тип данных
    values = params.values.map do |v|
      case v
      when true
        1
      when false
        0
      else
        v
      end
    end

    list = db.execute(
      "SELECT rowid, * FROM #{table} WHERE " +
        params.keys.map { |k| "#{k} = ?" }.join(" AND "),
      values
    )
    db.close

    list.map { |e| @@types[table].from_db_hash(e) }
  end

  def self.find_by(params)
    where(params).first
  end

  def self.from_db_hash
    raise NotImplementedError
  end

  def initialize(rowid: nil)
    @rowid = rowid
  end

  def save!
    exists? ? update! : insert!
  end

  def exists?
    !@rowid.nil?
  end

  def eql?(other)
    self.class == other.class && id == other.id
  end

  def hash
    id.hash
  end

  def id
    raise NotImplementedError
  end

  private

  def self.table
    raise NotImplementedError
  end

  def table
    raise NotImplementedError
  end

  def to_db_hash
    raise NotImplementedError
  end

  def update!
    db = SQLite3::Database.open(@@db_path)
    db.results_as_hash = true
    db.execute(
      "UPDATE #{table} " +
        "SET " + to_db_hash.keys.map { |k| "#{k} = ?" }.join(', ') +
        "WHERE rowid = ?",
      to_db_hash.merge({rowid: @rowid}).values
    )
    db.close
  end

  def insert!
    db = SQLite3::Database.open(@@db_path)
    db.results_as_hash = true
    db.execute(
      "INSERT INTO #{table} (" +
        to_db_hash.keys.join(',') +
        ") VALUES (" +
        ('?,'*to_db_hash.keys.size).chomp(',') +
        ")",
      to_db_hash.values
    )
    db.close
  end
end
