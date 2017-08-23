require 'rspec'
require 'ostruct'
require 'active_record'
conn = { adapter: 'sqlite3', database: ':memory:' }
ActiveRecord::Base.establish_connection(conn)
require 'lostfilm_api'

describe LostFilmAPI do
  let(:lf) { LostFilmAPI.new(session: 'some_session') }
  let(:params) { {lf_id: 329, title: 'Грешница', title_orig: 'The Sinner',
                 link: '/series/The_Sinner', favorited: true} }
  let(:series) { Series.new(params) }

  describe '.get_session' do
    context 'valid email and password' do
      let(:valid_cookie_string) { File.read("#{__dir__}/fixtures/cookie_valid.txt") }
      let(:response_body) { '{"name":"UserName","success":true,"result":"ok"}' }

      let(:response) { OpenStruct.new(headers: {'set-cookie' => valid_cookie_string},
                                       body: response_body) }

      it 'returns session' do
        allow(LostFilmAPI).to receive_messages(post: response)

        session = LostFilmAPI.get_session(email: 'email', password: 'pass')

        expect(session).to eq 'lf_session=valid_cookie_session'
      end
    end

    context 'invalid email or password' do
      let(:response) { OpenStruct.new(body: '{"error":3,"result":"ok"}') }

      it 'raises LostFilmAPI::AuthorizationError exception' do
        allow(LostFilmAPI).to receive_messages(post: response)

        expect do
          LostFilmAPI.get_session(email: 'email', password: 'pass')
        end.to raise_exception LostFilmAPI::AuthorizationError
      end
    end
  end

  describe '#initialize' do
    it 'assigns @session instance variable' do
      expect(lf.session).to eq 'some_session'
    end
  end

  describe '#authorized?' do
    it 'true when recieve valid answer from LF' do
      allow(lf).to receive_messages(get_http_request: '[]')

      expect(lf).to be_authorized
    end

    it 'false when recieve invalid answer from LF' do
      allow(lf).to receive_messages(get_http_request: '{"error":1}')

      expect(lf).to_not be_authorized
    end
  end

  describe '#get_series_list' do
    require_relative 'fixtures/fake_get_http_request_list'

    it 'returns list of Series objects' do
      series = lf.get_series_list(favorited_only: false)

      expect(series.size).to eq 10
      expect(series).to all be_instance_of Series
      expect(series.map(&:lf_id)).to contain_exactly(272, 312, 235, 190, 163,
                                                  271, 316, 254, 282, 233)
    end
  end

  describe '#get_episodes_list' do
    let(:source) { "#{__dir__}/fixtures/get_episodes_list.html" }
    let(:content) { File.read(source) }

    context 'with non-object option' do
      it 'returns list of episodes ID\'s' do
        allow(lf).to receive_messages(get_http_request: content)

        episodes = lf.get_episodes_list(series, non_objects: true)

        expect(episodes).to contain_exactly('329-1-1', '329-1-2', '329-1-3')
      end
    end

    context 'without non-object-option' do
      it 'returns list of episodes' do
        allow(lf).to receive_messages(get_http_request: content)
        allow(lf).to receive_messages(get_watched_episodes_list: ['329-1-1'])

        episodes = lf.get_episodes_list(series)

        expect(episodes).to all be_instance_of Episode
        expect(episodes.map(&:lf_id)).to contain_exactly('329-1-1', '329-1-2', '329-1-3')
      end
    end
  end

  describe '#get_watched_episodes_list' do
    context 'session is invalid' do
      it 'raises an LostFilmAPI::NotAuthorizedError exception' do
        allow(lf).to receive_messages(authorized?: false)

        expect do
          lf.get_watched_episodes_list(series)
        end.to raise_exception LostFilmAPI::NotAuthorizedError
      end
    end

    context 'session is valid' do
      let(:response) { '{"data":["329-1-1"]}' }

      context 'with non-object option' do
        it 'returns list of episodes ID\'s' do
          allow(lf).to receive_messages(get_http_request: response, authorized?: true)

          episodes = lf.get_watched_episodes_list(series, non_objects: true)

          expect(episodes).to contain_exactly('329-1-1')
        end
      end

      context 'without non-object-option' do
        it 'returns list of episodes' do
          allow(lf).to receive_messages(get_http_request: response, authorized?: true)

          episodes = lf.get_watched_episodes_list(series)

          expect(episodes).to all be_instance_of Episode
          expect(episodes.map(&:lf_id)).to contain_exactly('329-1-1')
        end
      end
    end
  end

  describe '#get_unwatched_episodes_list' do
    context 'with non-object option' do
      it 'returns list of episodes ID\'s' do
        allow(lf).to receive_messages(get_episodes_list: %w(329-1-1 329-1-2 329-1-3))
        allow(lf).to receive_messages(get_watched_episodes_list: ['329-1-1'])

        episodes = lf.get_unwatched_episodes_list(series, non_objects: true)

        expect(episodes).to contain_exactly('329-1-2', '329-1-3')
      end
    end

    context 'without non-object-option' do
      it 'returns list of episodes' do
        allow(lf).to receive_messages(get_episodes_list: %w(329-1-1 329-1-2 329-1-3))
        allow(lf).to receive_messages(get_watched_episodes_list: ['329-1-1'])

        episodes = lf.get_unwatched_episodes_list(series)
        expect(episodes).to all be_instance_of Episode
        expect(episodes.map(&:lf_id)).to contain_exactly('329-1-2', '329-1-3')
      end
    end
  end

  describe '#download' do
    context 'session is invalid' do
      it 'raises an LostFilmAPI::NotAuthorizedError exception' do
        allow(lf).to receive_messages(authorized?: false)

        expect do
          lf.download('link', quality: '', folder: '')
        end.to raise_exception LostFilmAPI::NotAuthorizedError
      end
    end

    context 'session is valid' do
      let(:response) { File.read("#{__dir__}/fixtures/file_content") }
      let(:file_path) { "#{__dir__}/fixtures" }
      let(:file_name) { '1.torrent' }
      let(:file) { File.join(file_path, file_name) }

      before do
        File.delete(file) if File.exist?(file)
      end

      after do
        File.delete(file) if File.exists?(file)
      end

      it 'downloads file' do
        allow(lf).to receive_messages(authorized?: true)
        allow(lf).to receive_messages(get_redirect_link: 'l', get_download_link: 'l')
        allow(lf).to receive_messages(get_http_request: response)
        allow(lf).to receive_messages(get_file_name: '1.torrent')

        lf.download('link', quality: '', folder: file_path)

        expect(File).to exist(file)
      end
    end
  end
end
