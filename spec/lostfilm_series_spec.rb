require 'rspec'
require 'fileutils'
require 'lostfilm_episode'
require 'lostfilm_series'

describe LostFilmSeries do
  let(:db_source) { "#{__dir__}/fixtures/existing_db.sqlite" }
  let(:db_path) { "#{__dir__}/fixtures/db.sqlite" }
  let(:params1) { {id: 700, title: 'Лучший сериал', title_orig: 'Best Series',
                   link: '/series/Best_Series', favorited: false, followed: false,
                   episodes: ['ep1', 'ep2', 'ep3']} }
  let(:params2) { {id: 701, title: 'Худший сериал', title_orig: 'Worst Series',
                   link: '/series/Worst_Series', favorited: true} }
  let(:series1) { LostFilmSeries.new(params1) }
  let(:series2) { LostFilmSeries.new(params2) }

  before do
    FileUtils.copy_file(db_source, db_path)
    DBElement.prepare_db!(db_path)
  end

  after do
    File.delete(db_path) if File.exist?(db_path)
  end

  describe '#initialize' do
    it 'assigns values to instance variables' do
      expect(series1.id).to eq 700
      expect(series1.title).to eq 'Лучший сериал'
      expect(series1.title_orig).to eq 'Best Series'
      expect(series1.link).to eq '/series/Best_Series'
      expect(series1.favorited).to be false
      expect(series1.followed).to be false
      expect(series1.episodes).to contain_exactly('ep1', 'ep2', 'ep3')
    end

    it 'set @followed equal to @favorited if @followed is nil' do
      expect(series2.followed). to eq series2.followed
    end
  end

  describe '#favorited?' do
    it 'returns @favorited value' do
      expect(series1).to_not be_favorited
      expect(series2).to be_favorited
    end
  end

  describe '#followed?' do
    it 'returns @followed value' do
      expect(series1).to_not be_followed
      expect(series2).to be_followed
    end
  end

  describe '.all' do
    it 'returns all series from DB' do
      series = LostFilmSeries.all
      expect(series.size).to eq LostFilmSeries.count
      expect(series).to all be_instance_of LostFilmSeries
    end
  end

  describe '.where' do
    context 'data found in DB' do
      let(:series_list) { LostFilmSeries.where(favorited: true, followed: false) }

      it 'returns array of series' do
        expect(series_list).to all be_instance_of LostFilmSeries
      end

      it 'returns series with right parameters' do
        expect(series_list).to all be_favorited
        expect(series_list.map(&:followed?)).to all be false
      end

      it 'returns right count of series' do
        expect(series_list.size).to eq 33
      end
    end

    context 'data not found in DB' do
      let(:series_list) { LostFilmSeries.where(id: 800) }

      it 'returns empty array' do
        expect(series_list).to be_empty
      end
    end
  end

  describe '.find_by' do
    context 'data found in DB' do
      let(:series) { LostFilmSeries.find_by(favorited: true, followed: false) }

      it 'returns instance of LostFilmSeries' do
        expect(series).to be_instance_of LostFilmSeries
      end

      it 'returns series with right parameters (first found)' do
        expect(series.id).to eq 272
        expect(series.title).to eq '11.22.63'
        expect(series.title_orig).to eq '11.22.63'
        expect(series.link).to eq '/series/11-22-63'
        expect(series).to be_favorited
        expect(series).to_not be_followed
        expect(series.episodes).to be_empty
      end
    end

    context 'data not found in DB' do
      let(:series) { LostFilmSeries.find_by(id: 800) }

      it 'returns nil' do
        expect(series).to be_nil
      end
    end
  end

  describe '.count' do
    it 'returns count of DB entrances' do
      expect(LostFilmSeries.count).to eq 257
    end
  end

  describe '#save!' do
    context 'series not exists in DB' do
      it 'add new series to DB' do
        expect { series1.save! }.to change(LostFilmSeries, :count).by(1)
      end
    end

    context 'episode already exists in DB' do
      it 'don\'t add new episode to DB' do
        series = LostFilmSeries.find_by(id: 271)
        expect { series.save! }.to_not change(LostFilmSeries, :count)
      end
    end
  end
end
