require 'spec_helper'

describe Language do
  
  describe '#full_name' do
    context 'a language' do
      before do
        @language = Language.new()
      end
      it 'has their name displayed as-is' do
        expect(@language.to_s).to eq(nil)
      end
    end

  end

  describe '#as_json' do

    context 'a language with nothing set' do
      before do
        @language = Language.new()
      end
      it 'returns json' do
        # can do better than this. Probably by using https://github.com/collectiveidea/json_spec
        expect(@language.as_json.to_s.size).to be > 10
      end
    end

  end

#  describe '#uri' do
#
#    context 'a language with nothing set' do
#      before do
#        @language = Language.new()
#      end
#      it 'has no uri' do
#        expect(@language.uri).to eq(nil)
#      end
#    end
#
#    context 'a language with an id' do
#      before do
#        @language = Language.new(id: 13)
#      end
#      it 'has a uri' do
#        # this is not ideal response. It should depend on the output format
#        expect(@country.uri).to eq('http://openplaques.org/places/aa.json')
#      end
#    end
#
#  end

end
