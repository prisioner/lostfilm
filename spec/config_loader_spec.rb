require 'rspec'
require 'fileutils'
require 'config_loader'

describe ConfigLoader do
  let(:config) { ConfigLoader.new(file: file) }

  describe '#initialize' do
    let(:session) { 'some_session' }
    let(:db_path) { File.join('D:', 'downloads', 'lostfilm.sqlite') }
    let(:download_folder) { File.join('D:', 'downloads') }
    let(:series_list_autoupdate) { false }

    let(:default_quality_opts) { %w(1080 HD MP4 SD) }
    let(:default_orig_titles) { false }

    context 'full five given' do
      let(:file) { "#{__dir__}/fixtures/full_config_file.yml" }

      let(:quality_options) { %w(MP4 HD 1080) }
      let(:original_titles) { true }

      it 'assigns file values to config options' do
        expect(config.session).to eq session
        expect(config.db_path).to eq db_path
        expect(config.download_folder).to eq download_folder
        expect(config.quality_priority).to eq quality_options
        expect(config.series_list_autoupdate).to eq series_list_autoupdate
        expect(config.original_titles).to eq original_titles
      end
    end

    context 'not full file given' do
      let(:file) { "#{__dir__}/fixtures/not_full_config_file.yml" }

      it 'assigns existing file values to config options' do
        expect(config.session).to eq session
        expect(config.db_path).to eq db_path
        expect(config.download_folder).to eq download_folder
        expect(config.series_list_autoupdate).to eq series_list_autoupdate
      end

      it 'assigns default values to missing config options' do
        expect(config.quality_priority).to eq default_quality_opts
        expect(config.original_titles).to eq default_orig_titles
      end
    end

    context 'not existed file given' do
      let(:file) { "#{__dir__}/fixtures/not_existed_file.yml" }
      let(:default_session) { '' }
      let(:default_db_path) { File.absolute_path(File.join(__dir__, '..', 'lostfilm.sqlite')) }
      let(:default_folder) { File.absolute_path(File.join(__dir__, '..', 'downloads')) }
      let(:default_autoupdate) { true }

      before do
        File.delete(file) if File.exist?(file)
      end

      after do
        File.delete(file) if File.exists?(file)
      end

      it 'creates config file' do
        config
        expect(File).to exist(file)
      end

      it 'assigns default values to all config options' do
        expect(config.session).to eq default_session
        expect(config.db_path).to eq default_db_path
        expect(config.download_folder).to eq default_folder
        expect(config.quality_priority).to eq default_quality_opts
        expect(config.series_list_autoupdate).to eq default_autoupdate
        expect(config.original_titles).to eq default_orig_titles
      end
    end
  end

  describe '#save!' do
    let(:source) { "#{__dir__}/fixtures/full_config_file.yml" }
    let(:file) { "#{__dir__}/fixtures/some_config_file.yml" }
    let(:content) { File.read(file, encoding: 'utf-8') }

    before do
      FileUtils.copy_file(source, file)
    end

    it 'makes changes in config file' do
      config.session = 'another_session'
      config.save!
      expect(content).to include ':session: another_session'
      expect(content).to_not include ':session: some_session'
    end
  end
end
