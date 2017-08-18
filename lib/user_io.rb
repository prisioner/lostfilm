require 'io/console'

module UserIO
  # Этот код необходим только при использовании русских букв на Windows
  if Gem.win_platform?
    Encoding.default_external = Encoding.find(Encoding.locale_charmap)
    Encoding.default_internal = __ENCODING__

    [STDIN, STDOUT].each do |io|
      io.set_encoding(Encoding.default_external, Encoding.default_internal)
    end
  end

  module_function

  def puts_string(some_string)
    puts some_string
  end

  def print_string(some_string)
    print some_string
  end

  def out_text(*some_strings, separator: "\n", new_line_before: true, empty_line_after: false)
    puts if new_line_before
    puts some_strings.join(separator)
    puts if empty_line_after
  end

  def get_input(some_text = nil)
    print some_text if some_text
    STDIN.gets.chomp
  end

  def get_pass(some_text = nil)
    STDIN.getpass(some_text)
  end
end
