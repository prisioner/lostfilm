require 'rspec'
require 'fileutils'
require 'lostfilm_episode'

describe LostFilmEpisode do
  let(:db_source) { "#{__dir__}/fixtures/existing_db.sqlite" }
  let(:db_path) { "#{__dir__}/fixtures/db.sqlite" }
  let(:params1) { {id: '999-1-1', series_id: 999, watched: false, downloaded: false} }
  let(:params2) { {id: '998-1-2', watched: true} }
  let(:episode1) { LostFilmEpisode.new(params1) }
  let(:episode2) { LostFilmEpisode.new(params2) }

  before do
    FileUtils.copy_file(db_source, db_path)
    DBElement.prepare_db!(db_path)
  end

  after do
    File.delete(db_path) if File.exist?(db_path)
  end

  describe '#initialize' do
    it 'assigns values to instance variables: @id, @series_id, @watched, @downloaded' do
      expect(episode1.id).to eq '999-1-1'
      expect(episode1.series_id).to eq 999
      expect(episode1.watched).to be false
      expect(episode1.downloaded).to be false
    end

    it 'extract @series_id from @id if @series_id is nil' do
      expect(episode2.series_id).to eq 998
    end

    it 'set @downloaded equal to @watched if @downloaded is nil' do
      expect(episode2.downloaded). to eq episode2.watched
    end
  end

  describe '#watched?' do
    it 'returns @watched value' do
      expect(episode1).to_not be_watched
      expect(episode2).to be_watched
    end
  end

  describe '#downloaded?' do
    it 'returns @downloaded value' do
      expect(episode1).to_not be_downloaded
      expect(episode2).to be_downloaded
    end
  end

  describe '#download_link' do
    it 'returns download url path' do
      expect(episode2.download_link).to eq '/v_search.php?c=998&s=1&e=2'
    end
  end

  describe '.all' do
    it 'returns all episodes from DB' do
      episodes = LostFilmEpisode.all
      expect(episodes.size).to eq LostFilmEpisode.count
      expect(episodes).to all be_instance_of LostFilmEpisode
    end
  end

  describe '.where' do
    context 'data found in DB' do
      let(:episodes) { LostFilmEpisode.where(series_id: 271) }

      it 'returns array of episodes' do
        expect(episodes).to all be_instance_of LostFilmEpisode
      end

      it 'returns episodes with right parameters' do
        expect(episodes.map(&:series_id)).to all eq 271
      end

      it 'returns right count of episodes' do
        expect(episodes.size).to eq 10
      end
    end

    context 'data not found in DB' do
      let(:episodes) { LostFilmEpisode.where(series_id: 800) }

      it 'returns empty array' do
        expect(episodes).to be_empty
      end
    end
  end

  describe '.find_by' do
    context 'data found in DB' do
      let(:episode) { LostFilmEpisode.find_by(series_id: 271) }

      it 'returns instance of LostFilmEpisode' do
        expect(episode).to be_instance_of LostFilmEpisode
      end

      it 'returns episode with right parameters (first found)' do
        expect(episode.id).to eq '271-1-10'
        expect(episode.series_id).to eq 271
        expect(episode.watched).to be false
        expect(episode.downloaded).to be true
      end
    end

    context 'data not found in DB' do
      let(:episode) { LostFilmEpisode.find_by(series_id: 800) }

      it 'returns nil' do
        expect(episode).to be_nil
      end
    end
  end

  describe '.count' do
    it 'returns count of DB entrances' do
      expect(LostFilmEpisode.count).to eq 186
    end
  end

  describe '#save!' do
    context 'episode not exists in DB' do
      it 'add new episode to DB' do
        expect { episode1.save! }.to change(LostFilmEpisode, :count).by(1)
      end
    end

    context 'episode already exists in DB' do
      it 'don\'t add new episode to DB' do
        episode = LostFilmEpisode.find_by(series_id: 271)
        expect { episode.save! }.to_not change(LostFilmEpisode, :count)
      end
    end
  end
end
