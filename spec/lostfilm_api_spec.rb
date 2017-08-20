require 'rspec'
require 'ostruct'
require 'lostfilm_api'

describe LostFilmAPI do
  let(:lf) { LostFilmAPI.new(session: 'some_session') }

  describe '.get_session' do
    context 'valid email and password' do
      let(:valid_cookie_string) { File.read("#{__dir__}/fixtures/cookie_valid.txt") }
      let(:response_body) { '{"name":"UserName","success":true,"result":"ok"}' }
      let(:response) { OpenStruct.new('set-cookie': valid_cookie_string, body: response_body) }

      it 'returns session' do
        allow(Net::HTTP).to receive_messages(post_form: response)
        session = LostFilmAPI.get_session(email: 'email', password: 'pass')
        expect(session).to eq 'lf_session=valid_cookie_session'
      end
    end

    context 'invalid email or password' do
      let(:response) { OpenStruct.new(body: '{"error":3,"result":"ok"}') }

      it 'raises LostFilmAPI::AuthorizationError exception' do
        allow(Net::HTTP).to receive_messages(post_form: response)
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

    it 'returns list of LostFilmSeries objects' do
      series = lf.get_series_list

      expect(series.size).to eq 10
      expect(series).to all be_instance_of LostFilmSeries
      expect(series.map(&:id)).to contain_exactly(272, 312, 235, 190, 163, 271, 316, 254, 282, 233)
    end
  end

  describe '#get_episodes_list' do
    let(:source) { "#{__dir__}/fixtures/get_episodes_list.html" }
    let(:content) { File.read(source, encoding: 'urf-8') }

    context 'with non-object option' do
      allow(lf).to receive_messages(get_http_request: content)

      expect(lf.get_)
    end

    context 'without non-object-option' do

    end
  end
end
