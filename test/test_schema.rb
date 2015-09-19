# Test Schema.

require_relative 'helper'
require 'miguel/schema'

describe Miguel::Schema do

  DATA_DIR = File.expand_path( "#{__FILE__}/../data" )

  def data( name )
    "#{DATA_DIR}/#{name}"
  end

  should 'load and dump schema properly' do
    schema = Miguel::Schema.load( data( 'schema.rb' ) )
    schema.dump.to_s.should == File.read( data( 'schema.txt' ) )
  end

  should 'allow changing default schema options temporarily' do
    schema = Miguel::Schema.load( data( 'simple.rb' ), unsigned_keys: true, mysql_timestamps: true )
    schema.dump.to_s.should == File.read( data( 'simple_mysql.txt' ) )
    Miguel::Schema.new.opts.should.be.empty

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    schema.dump.to_s.should == File.read( data( 'simple.txt' ) )
  end

  should 'allow changing default schema options permanently' do
    Miguel::Schema.default_options.should == {}

    Miguel::Schema.set_default_options( unsigned_keys: true, mysql_timestamps: true )
    Miguel::Schema.new( test: true ).opts.should == { unsigned_keys: true, mysql_timestamps: true, test: true }
    Miguel::Schema.default_options.should == { unsigned_keys: true, mysql_timestamps: true }

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    schema.dump.to_s.should == File.read( data( 'simple_mysql.txt' ) )

    Miguel::Schema.default_options = nil
    Miguel::Schema.default_options.should == {}
    Miguel::Schema.new.opts.should.be.empty

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    schema.dump.to_s.should == File.read( data( 'simple.txt' ) )
  end

end

# EOF #
