require_relative 'user_io'

module LostFilmClient
  module_function

  def auth
    UserIO.puts_string "Авторизация на сайте Lostfilm.tv"
    UserIO.puts_string "Внимание: приложение НЕ хранит Ваш пароль"

    email = UserIO.get_input("Введите ваш email: ")
    password = UserIO.get_pass("Введите ваш пароль: ")
    session = LostFilmAPI.get_session(email: email, password: password)

    UserIO.puts_string "Авторизация прошла успешно!"
    session
  end
end
