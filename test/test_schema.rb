# Test Schema.

require 'miguel/schema'

describe Miguel::Schema do

  SCHEMA = File.expand_path( "#{__FILE__}/../data/schema.rb" )
  OUTPUT = File.expand_path( "#{__FILE__}/../data/schema.txt" )

  should 'load and dump schema properly' do
    schema = Miguel::Schema.load( SCHEMA )
    schema.dump.to_s.should == File.read( OUTPUT )
  end

end

# EOF #
