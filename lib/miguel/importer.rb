# Sequel schema import.

require 'miguel/schema'

module Miguel

  # Class for importing database schema from Sequel database.
  class Importer

    # The database we operate upon.
    attr_reader :db

    # Create new instance for importing schema from given database.
    def initialize( db )
      @db = db
    end

    private

    # Which characters we convert when parsing enum values.
    # Quite likely not exhaustive, but sufficient for our purposes.
    ESCAPED_CHARS = {
      "''" => "'",
      "\\\\" => "\\",
      "\\n" => "\n",
      "\\t" => "\t",
    }

    # Regexp matching escaped sequences in enum values.
    ESCAPED_CHARS_RE = /''|\\./

    # Parse the element values for enum/set types.
    def parse_elements( string )
      string.scan(/'((?:[^']|'')*)'/).flatten.map do
        |x| x.gsub( ESCAPED_CHARS_RE ){ |c| ESCAPED_CHARS[ c ] || c }
      end
    end

    # Convert given MySQL database type to type and optional options used by our schema definitions.
    def revert_mysql_type( type )
      case type
      when /\Aint\(\d+\)\z/
        return :integer, :default_size => 11
      when /\Aint\(\d+\) unsigned\z/
        return :integer, :unsigned => true, :default_size => 10
      when /\Abigint\(\d+\)\z/
        return :bigint, :default_size => 20
      when /\Abigint\(\d+\) unsigned\z/
        return :bigint, :unsigned => true, :default_size => 20
      when /\Adecimal\(\d+,\d+\)\z/
        return :decimal, :default_size => [ 10, 0 ]
      when /\A(enum|set)\((.*)\)\z/
        return $1.to_sym, :elements => parse_elements( $2 )
      end
    end

    # Convert given SQLite database type to type and optional options used by our schema definitions.
    def revert_sqlite_type( type )
      case type
      when /\Ainteger UNSIGNED\z/
        return :integer, :unsigned => true
      end
    end

    # Convert given Postgres database type to type and optional options used by our schema definitions.
    def revert_postgres_type( type )
      case type
      when /\Acharacter varying/
        return :String, :default_size => 255
      when /\Acharacter/
        return :String, :fixed => true, :default_size => 255
      when /\Atext\z/
        return :String, :text => true
      when /\Abytea\z/
        return :blob
      when /\Atimestamp/
        return :timestamp
      end
    end

    # Convert given generic database type to type and optional options used by our schema definitions.
    def revert_generic_type( type )
      case type
      when /\Avarchar/
        return :String, :default_size => 255
      when /\Achar/
        return :String, :fixed => true, :default_size => 255
      when /\Atext\z/
        return :String, :text => true
      when /\A(\w+)\([\s\d,]+\)\z/
        return $1.to_sym
      when /\A\w+\z/
        return type.to_sym
      end
    end

    # Convert given database type to type and optional options used by our schema definitions.
    # The ruby type provided serves as a hint of what Sequel's idea of the type is.
    def revert_type_literal_internal( type, ruby_type )
      return :boolean, :default_size => 1 if ruby_type == :boolean

      method = "revert_#{db.database_type}_type"
      specific_type = send( method, type ) if respond_to?( method, true )

      specific_type || revert_generic_type( type ) || ruby_type
    end

    # Convert given database type to type and optional options used by our schema definitions.
    # The ruby type provided serves as a hint of what Sequel's idea of the type is.
    def revert_type_literal( type, ruby_type )

      case type
      when /\(\s*(\d+)\s*\)/
        size = $1.to_i
      when /\(([\s\d,]+)\)/
        size = $1.split( ',' ).map{ |x| x.to_i }
      end

      type, opts = revert_type_literal_internal( type, ruby_type )

      opts ||= {}

      default_size = opts.delete( :default_size )

      if size and size != default_size
        opts[ :size ] = size
      end

      [ type, opts ]
    end

    # Convert given database default of given type to default used by our schema definitions.
    def revert_default( type, default, ruby_default )
      if type.to_s =~ /date|time/
        case default
        when /CURRENT_TIMESTAMP/i
          # This matches our use of MySQL timestamps in schema definitions.
          return Sequel.lit('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
        end
      end

      default = ruby_default unless ruby_default.nil?

      case default
      when /'(.*?)'::integer/
        return $1.to_i
      when nil, String, Numeric, TrueClass, FalseClass
        return default
      when DateTime
        return default.strftime( '%F %T' )
      else
        return default.to_s
      end
    end

    # Import indexes of given table.
    def import_indexes( table )
      # Foreign keys also automatically create indexes, which we must exclude when importing.
      # But only if they look like indexes named by the automatic foreign key naming convention.
      foreign_key_indexes = table.foreign_keys.map{ |x| x.columns if x.columns.size == 1 }.compact
      for name, opts in db.indexes( table.name )
        opts = opts.dup
        opts[ :name ] = name
        columns = opts.delete( :columns )
        next if ( ! opts[ :unique ] ) && foreign_key_indexes.include?( columns ) && name == columns.first
        # Sequel currently doesn't provide info about fulltext indexes, so we have to rely on properly used names.
        opts[ :type ] = :full_text if name =~ /_fulltext$/
        opts.delete( :deferrable ) unless opts[ :deferrable ]
        table.add_index( columns, opts )
      end
    end

    # Import foreign keys of given table.
    def import_foreign_keys( table )
      for opts in db.foreign_key_list( table.name )
        opts = opts.dup
        name = opts.delete( :name )
        columns = opts.delete( :columns )
        table_name = opts.delete( :table )
        opts.delete( :deferrable ) unless opts[ :deferrable ]
        table.add_foreign_key( columns, table_name, opts )
      end
    end

    # Options which are ignored for columns.
    # These are usually just schema hints which the user normally doesn't specify.
    IGNORED_OPTS = [ :max_length, :oid ]

    # Import column type and options.
    def import_column_type_and_options( opts )
      opts = opts.dup

      # Discard anything we don't need.

      opts.delete_if{ |key, value| IGNORED_OPTS.include? key }

      # Import type.

      type = opts.delete( :type )
      db_type = opts.delete( :db_type )

      type, type_opts = revert_type_literal( db_type, type )
      opts.merge!( type_opts ) if type_opts

      # Import NULL option.

      opts[ :null ] = opts.delete( :allow_null )

      # Import default value.

      default = opts.delete( :default )
      ruby_default = opts.delete( :ruby_default )

      default = revert_default( type, default, ruby_default )

      opts[ :default ] = default unless default.nil?

      [ type, opts ]
    end

    # Import columns of given table.
    def import_columns( table )
      schema = db.schema( table.name )

      # Get info about primary key columns.

      primary_key_columns = schema.select{ |name, opts| opts[ :primary_key ] }

      multi_primary_key =  ( primary_key_columns.count > 1 )

      # Import each column in sequence.

      for name, opts in schema

        # Import column type and options.

        type, opts = import_column_type_and_options( opts )

        # Deal with primary keys, which is a bit obscure because of the auto-increment handling.

        primary_key = opts.delete( :primary_key )
        auto_increment = opts.delete( :auto_increment )

        if primary_key && ! multi_primary_key
          if auto_increment
            opts.delete( :default ) if opts[ :default ].to_s =~ /\Anextval/
            table.add_column( :primary_key, name, opts.merge( :type => type ) )
            next
          end
          opts[ :primary_key ] = primary_key
        end

        table.add_column( type, name, opts )
      end

      # Define multi-column primary key if necessary.
      # Note that Sequel currently doesn't preserve the primary key order, so neither can we.

      if multi_primary_key
        table.add_column( :primary_key, primary_key_columns.map{ |name, opts| name } )
      end
    end

    # Import all fields of given table.
    def import_table( table )
      # This must come first, so we can exclude foreign key indexes later.
      import_foreign_keys( table )
      import_indexes( table )
      import_columns( table )
    end

    public

    # Which tables we automatically ignore on import.
    IGNORED_TABLES = [ :schema_info ]

    # Import the database schema.
    def schema
      schema = Schema.new

      for name in db.tables
        next if IGNORED_TABLES.include? name
        table = schema.add_table( name )
        import_table( table )
      end

      schema
    end

  end

end

# EOF #
