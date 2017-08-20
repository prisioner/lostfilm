require 'rspec'
require 'db_element'
require 'lostfilm_series'
require 'lostfilm_episode'

describe DBElement do
  describe '.prepare_db!' do
    context 'existing DB file given' do
      let(:db_path) { "#{__dir__}/fixtures/existing_db.sqlite" }

      it 'doesn\'t make changes in DB file' do
        expect { DBElement.prepare_db!(db_path) }.to_not change{ File.size(db_path) }
      end
    end

    context 'not-existing DB file given' do
      let(:db_path) { "#{__dir__}/fixtures/not_existing_db.sqlite" }

      before do
        File.delete(db_path) if File.exists?(db_path)
        DBElement.prepare_db!(db_path)
      end

      after do
        File.delete(db_path) if File.exists?(db_path)
      end

      it 'creates DB file' do
        expect(File).to exist(db_path)
      end
    end
  end
end
