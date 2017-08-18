# encoding: utf-8

# Этот код необходим только при использовании русских букв на Windows
if Gem.win_platform?
  Encoding.default_external = Encoding.find(Encoding.locale_charmap)
  Encoding.default_internal = __ENCODING__

  [STDIN, STDOUT].each do |io|
    io.set_encoding(Encoding.default_external, Encoding.default_internal)
  end
end

require_relative 'lib/lostfilm_api'
require_relative 'lib/config_loader'
require 'optparse'
require 'io/console'

config = ConfigLoader.new
DBElement.prepare_db!(config.db_path)

options = {}

OptionParser.new do |opt|
  opt.banner = 'Использование: ruby lostfilm.rb [options]'

  opt.on('-h', '--help', 'Выводит эту справку') do
    puts opt
    exit
  end

  opt.on('-login', 'Запускает процесс авторизации') { options[:act] = :login }

  opt.on('--get-series-list [TYPE]', 'Загружает список сериалов (all - всех сериалов, fav(по умолчанию) - только избранных)') do |o|
    options[:act] = :get_list
    options[:type] = o.nil? ? :fav : o.to_sym
  end

end.parse!

config.save!
