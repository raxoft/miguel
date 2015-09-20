# Test Migrator.

require_relative 'helper'
require 'miguel/migrator'

describe Miguel::Schema do

  def load( name )
    Miguel::Schema.load( data( name ) )
  end

  should 'create changes needed to create schema' do
    schema = load( 'schema.rb' )
    changes = Miguel::Migrator.new.changes( Miguel::Schema.new, schema )
    changes.to_s.should == File.read( data( 'schema_bare.txt' ) )
  end

  should 'create changes needed to destroy schema' do
    schema = load( 'schema.rb' )
    changes = Miguel::Migrator.new.changes( schema, Miguel::Schema.new )
    changes.to_s.should == File.read( data( 'schema_down.txt' ) )
  end

  should 'create Sequel change migration' do
    schema = load( 'schema.rb' )
    migration = Miguel::Migrator.new.change_migration( Miguel::Schema.new, schema )
    migration.to_s.should == File.read( data( 'schema_change.txt' ) )
  end

  should 'create Sequel up/down migration' do
    schema = load( 'schema.rb' )
    migration = Miguel::Migrator.new.full_migration( Miguel::Schema.new, schema )
    migration.to_s.should == File.read( data( 'schema_full.txt' ) )
  end

  should 'create migrations to migrate from one schema to another' do
    m = Miguel::Migrator.new
    schema = Miguel::Schema.new
    SEQ_COUNT.times do |i|
      new_schema = load( "seq_#{i}.rb" )
      migration = m.full_migration( schema, new_schema )
      migration.to_s.should == File.read( data( "seq_#{i}.txt" ) )
      schema = new_schema
    end
  end

end

# EOF #
