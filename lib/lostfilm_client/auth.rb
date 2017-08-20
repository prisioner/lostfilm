require 'io/console'

module LostFilmClient
  def auth
    puts "Авторизация на сайте Lostfilm.tv"
    puts "Внимание: приложение НЕ хранит Ваш пароль"

    print "Введите ваш email: "
    email = STDIN.gets.chomp
    password = STDIN.getpass("Введите ваш пароль: ")
    session = LostFilmAPI.get_session(email: email, password: password)

    puts "Авторизация прошла успешно!"
    session
  end

  module_function :auth
end
