require 'sqlite3'

class DBElement
  attr_accessor :rowid

  # Необходимо переопределить в дочерних классах
  TABLE = nil       # название таблицы
  SQL_QUERY = nil   # запрос для создания таблицы

  # Типы элементов, заполняется из дочерних классов при инициализации
  @@types = {}

  # Сохраняет путь к БД в переменную класса
  # Готовит БД к работе - создаёт отсутствующие таблицы
  def self.prepare_db!(db_path)
    ## Сохраняем путь к БД
    @@db_path = db_path
    # Коннектимся
    db = SQLite3::Database.open(@@db_path)

    # Создаём таблицы, которых нет в БД
    @@types.each_value { |type| db.execute(type::SQL_QUERY) }

    # Отключаемся
    db.close
  end

  # Возвращает из БД все объекты своего класса
  def self.all
    db = SQLite3::Database.open(@@db_path)
    db.results_as_hash = true

    list = db.execute("SELECT rowid, * FROM #{table}")
    db.close

    list.map { |e| @@types[table].from_db_hash(e) }
  end

  # Возвращает из БД все объекты своего класса, которые соответствуют условию
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

  # Возвращает из БД первый объект своего класса, который соответствует условию
  def self.find_by(params)
    where(params).first
  end

  # Возвращает количество элементов в БД
  # В работе программы пока не используется, но упрощает тестирование
  def self.count
    db = SQLite3::Database.open(@@db_path)

    # Запрос вернёт [[count]]
    count = db.execute("SELECT COUNT(*) FROM #{table}").first.first
    db.close

    count
  end

  def initialize(rowid: nil)
    @rowid = rowid
  end

  # Сохраняемся в БД. Если запись есть - update, если нет - insert
  def save!
    exists? ? update! : insert!
  end

  # eql?, hash и id - реализованы для работы функции разности массивов
  def eql?(other)
    # Объекты идентичны, если идентичны их классы и ID в системе LostFilm.tv
    self.class == other.class && id == other.id
  end

  def hash
    id.hash
  end

  def id
    raise NotImplementedError
  end

  private

  def self.from_db_hash
    raise NotImplementedError
  end

  def self.table
    raise NotImplementedError
  end

  def table
    raise NotImplementedError
  end

  def to_db_hash
    raise NotImplementedError
  end

  # Проверяем, взята ли запись из БД
  def exists?
    !@rowid.nil?
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
