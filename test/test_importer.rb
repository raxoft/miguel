# Test Importer.

require_relative 'helper'
require 'miguel/importer'
require 'miguel/migrator'

require 'yaml'

describe Miguel::Importer do

  def database_options( db )
    case db.database_type
    when :mysql
      [
        {},
        { unsigned_keys: true },
        { mysql_timestamps: true },
        { mysql_timestamps: true, zero_timestamps: true },
        { mysql_timestamps: true, zero_timestamps: false },
        { zero_timestamps: true },
        { zero_timestamps: false },
      ]
    when :postgres
      [ signed_unsigned: true, skip_fulltext: true ]
    else
      [ skip_fulltext: true ]
    end
  end

  def load( name, opts = {} )
    Miguel::Schema.load( data( name ), opts )
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
    YAML.load_file( data( database_config ) ).map do |env, config|
      Sequel.connect( config )
    end
  end

  should 'correctly import schema from each supported database' do
    empty = Miguel::Schema.new
    for db in databases
      for opts in database_options( db )
        schema = load( 'schema.rb', opts )
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

end

# EOF #
