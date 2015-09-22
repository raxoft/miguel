# Test Importer.

require_relative 'helper'
require 'miguel/importer'
require 'miguel/migrator'

require 'yaml'

describe Miguel::Importer do

  def load( name )
    Miguel::Schema.load( data( name ) )
  end

  def get_changes( db, schema )
    importer = Miguel::Importer.new( db )
    Miguel::Migrator.new.changes( importer.schema, schema ).to_s
  end

  def apply_schema( db, schema )
    changes = get_changes( db, schema )
    db.instance_eval( changes )
  end

  def databases
    YAML.load_file( data( 'db.yml' ) ).map do |env, config|
      Sequel.connect( config )
    end
  end

  should 'correctly import schema from each supported database' do
    empty = Miguel::Schema.new
    schema = load( 'schema.rb' )
    for db in databases
      apply_schema( db, empty )
      get_changes( db, empty ).should.be.empty
      get_changes( db, schema ).should.not.be.empty
      apply_schema( db, schema )
      get_changes( db, schema ).should.be.empty
      get_changes( db, empty ).should.not.be.empty
      apply_schema( db, empty )
      get_changes( db, empty ).should.be.empty
      get_changes( db, schema ).should.not.be.empty
    end
  end

end

# EOF #
