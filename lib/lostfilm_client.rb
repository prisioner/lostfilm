require_relative 'lostfilm_api'

# авторизация
require_relative 'lostfilm_client/auth'
# смена статуса follow/unfollow
require_relative 'lostfilm_client/change_follow_status'
# загружаем новые эпизоды
require_relative 'lostfilm_client/get_new_episodes'
# загружаем список сериалов
require_relative 'lostfilm_client/get_series_list'
# показываем список сериалов
require_relative 'lostfilm_client/show_list'
# обновляем список эпизодов
require_relative 'lostfilm_client/update_episodes_list'

module LostFilmClient
end
