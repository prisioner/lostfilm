require 'sqlite3'

class DBElement
  attr_reader :row_id

  # Необходимо переопределить
  TABLE = nil

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

  def initialize(row_id: nil)
    @row_id = row_id
  end

  def exists?
    !@row_id.nil?
  end
end
