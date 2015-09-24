# Schema class.

require 'sequel'

require 'miguel/dumper'

module Miguel

  # Class for defining database schema.
  class Schema

    # String denoting zero time.
    ZERO_TIME = '0000-00-00 00:00:00'.freeze

    # Module for pretty printing of names, types, and especially options.
    module Output

      private

      def out_value( value )
        case value
        when Hash
          "{#{ value.map{ |k,v| "#{out_value( k )} => #{out_value( v )}" }.join( ', ' ) }}"
        when Array
          "[#{ value.map{ |v| out_value( v ) }.join( ', ' ) }]"
        when Sequel::LiteralString
          "Sequel.lit(#{value.to_s.inspect})"
        else
          value.inspect
        end
      end

      def out_hash( value, prefix = ', ' )
        return "" if value.empty?
        prefix.dup << value.map{ |k,v| "#{out_value( k )} => #{out_value( v )}" }.join( ', ' )
      end

      public

      def out_opts( prefix = ', ' )
        out_hash( opts, prefix )
      end

      def out_canonic_opts( prefix = ', ' )
        out_hash( canonic_opts, prefix )
      end

      def out_default_opts( prefix = ', ' )
        out_hash( default_opts, prefix )
      end

      def out_name
        name.inspect
      end

      def out_type
        type.to_s =~ /\A[A-Z]/ ? type.to_s : type.inspect
      end

      def out_columns
        columns.inspect
      end

      def out_table_name
        table_name.inspect
      end

      def out_default
        out_value(default)
      end
    end

    # Class representing single database column.
    class Column

      include Output

      # Column type, name and options.
      attr_reader :type, :name, :opts

      # Create new column with given type and name.
      def initialize( type, name, opts = {} )
        @type = type
        @name = name
        @opts = opts
      end

      # Test if the column is in fact just a primary key constraint.
      def primary_key_constraint?
        type == :primary_key && name.is_a?( Array )
      end

      # Get the column default.
      def default
        d = opts[ :default ]
        d = type_default if d.nil? && ! allow_null
        d
      end

      # Get default default for column type.
      def type_default
        case canonic_type
        when :string
          ""
        when :boolean
          false
        when :enum, :set
          [ *opts[ :elements ], "" ].first
        else
          0
        end
      end

      # Check whether the column allow NULL values.
      def allow_null
        allow = opts[ :null ]
        allow.nil? || allow
      end

      # Options which are not relevant to type specification.
      NON_TYPE_OPTS = [ :null, :default ]

      # Get opts relevant to the column type only (excludes :null and :default).
      def type_opts
        opts.reject{ |key, value| NON_TYPE_OPTS.include? key }
      end

      # Canonic names of some builtin ruby types.
      CANONIC_TYPES = {
        :fixnum => :integer,
        :bignum => :bigint,
        :bigdecimal => :decimal,
        :numeric => :decimal,
        :float => :double,
        :file => :blob,
        :trueclass => :boolean,
        :falseclass => :boolean,
      }

      # Get the canonic type name, for type comparison.
      def canonic_type
        t = type.to_s.downcase.to_sym
        CANONIC_TYPES[ t ] || t
      end

      # Convert given size into its canonic form.
      def canonic_size( size )
        if canonic_type == :decimal && size.is_a?( Integer )
          [ size, 0 ]
        else
          size
        end
      end

      # Default options implied for certain types.
      DEFAULT_OPTS = {
        :string => { :size => 255 },
        :bigint => { :size => 20 },
        :decimal => { :size => [ 10, 0 ] },
        :integer => { :unsigned => false },
        :time => { :only_time => true },
        :primary_key => { :unsigned => false, :type => :integer },
      }

      # Options which are ignored for columns.
      # These usually relate to the associated foreign key constraints, not the column itself.
      IGNORED_OPTS = [ :key ]

      # Get the column options in a canonic way.
      def canonic_opts
        return {} if primary_key_constraint?
        o = { :type => canonic_type, :default => default, :null => true }
        o.merge!( DEFAULT_OPTS[ canonic_type ] || {} )
        o.merge!( opts )
        o[ :size ] = canonic_size( o[ :size ] )
        o.delete_if{ |key, value| IGNORED_OPTS.include? key }
      end

      # Get options with default value included.
      def default_opts
        { :default => default }.merge( opts )
      end

      # Compare one column with another one.
      def == other
        other.is_a?( Column ) &&
        name == other.name &&
        canonic_type == other.canonic_type &&
        canonic_opts == other.canonic_opts
      end

      # Dump column definition.
      def dump( out )
        out << "#{type} #{out_name}#{out_opts}"
      end

    end

    # Class representing database index.
    class Index

      include Output

      # Index column(s) and options.
      attr_reader :columns, :opts

      # Create new index for given column(s).
      def initialize( columns, opts = {} )
        @columns = [ *columns ]
        @opts = opts
      end

      # Options we ignore when comparing.
      IGNORED_OPTS = [ :null ]

      # Get the index options, in a canonic way.
      def canonic_opts
        o = { :unique => false }
        o.merge!( opts )
        o.delete_if{ |key, value| IGNORED_OPTS.include? key }
      end

      # Compare one index with another one.
      def == other
        other.is_a?( Index ) &&
        columns == other.columns &&
        canonic_opts == other.canonic_opts
      end

      # Dump index definition.
      def dump( out )
        out << "index #{out_columns}#{out_opts}"
      end

    end

    # Class representing foreign key constraint.
    class ForeignKey

      include Output

      # Key's column(s), the target table name and options.
      attr_reader :columns, :table_name, :opts

      # Create new foreign key for given columns referring to given table.
      def initialize( columns, table_name, opts = {} )
        @columns = [ *columns ]
        @table_name = table_name
        @opts = opts
        if key = opts[ :key ]
          opts[ :key ] = [ *key ]
        end
      end

      # Options we ignore when comparing.
      # These are usually tied to the underlying column, not constraint.
      IGNORED_OPTS = [ :null, :unsigned, :type, :default ]

      # Get the foreign key options, in a canonic way.
      def canonic_opts
        o = { :on_update => :no_action, :on_delete => :no_action }
        o.merge!( opts )
        o.delete_if{ |key, value| IGNORED_OPTS.include? key }
      end

      # Compare one foreign key with another one.
      def == other
        other.is_a?( ForeignKey ) &&
        columns == other.columns &&
        table_name == other.table_name &&
        canonic_opts == other.canonic_opts
      end

      # Dump foreign key definition.
      def dump( out )
        out << "foreign_key #{out_columns}, #{out_table_name}#{out_opts}"
      end

    end

    # Class representing database table.
    class Table

      include Output

      # Helper class used to evaluate the +add_table+ block.
      # Also implements the timestamping helper.
      class Context

        # Create new context for given table.
        def initialize( table )
          @table = table
        end

        # Send anything unrecognized as new definition to our table.
        def method_missing( name, *args )
          @table.add_definition( name, *args )
        end

        # The +method_missing+ doesn't take care of constant like methods (like String :name),
        # so those have to be defined explicitly for each such supported type.
        for type in Sequel::Schema::Generator::GENERIC_TYPES
          class_eval( "def #{type}(*args) ; @table.add_definition(:#{type},*args) ; end", __FILE__, __LINE__ )
        end

        # Create the default timestamp fields.
        def timestamps
          opts = @table.schema.opts
          if opts[ :mysql_timestamps ]
            # Unfortunately, MySQL allows only either automatic create timestamp
            # (DEFAULT CURRENT_TIMESTAMP) or automatic update timestamp (DEFAULT
            # CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP), but not both - one
            # has to be updated manually anyway. So we choose to have the update timestamp
            # automatically updated, and let the create one to be set manually.
            # Also, Sequel doesn't currently honor :on_update for column definitions,
            # so we have to use default literal to make it work. Sigh.
            timestamp :create_time, :null => false, :default => ZERO_TIME
            timestamp :update_time, :null => false, :default => Sequel.lit( 'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP' )
          else
            Time :create_time
            Time :update_time
          end
        end
      end

      # Schema to which this table belongs.
      attr_reader :schema

      # Name of the table.
      attr_reader :name

      # List of table indices and foreign keys.
      attr_reader :indexes, :foreign_keys

      # Create new table with given name belonging to given schema.
      def initialize( schema, name )
        @schema = schema
        @name = name
        @columns = {}
        @indexes = []
        @foreign_keys = []
      end

      # Get all columns.
      def columns
        @columns.values
      end

      # Get names of all table columns.
      def column_names
        @columns.keys
      end

      # Get given named columns.
      def named_columns( names )
        @columns.values_at( *names )
      end

      # Add column definition.
      def add_column( type, name, *args )
        fail( ArgumentError, "column #{name} in table #{self.name} is already defined" ) if @columns[ name ]
        @columns[ name ] = Column.new( type, name, *args )
      end

      # Add index definition.
      def add_index( columns, *args )
        @indexes << Index.new( columns, *args )
      end

      # Add foreign key definition.
      def add_foreign_key( columns, table_name, *args )
        add_column( :integer, columns, *args ) unless columns.is_a? Array
        @foreign_keys << ForeignKey.new( columns, table_name, *args )
      end

      # Add definition of column, index or foreign key.
      def add_definition( name, *args )
        name, *args = schema.apply_defaults( self.name, name, *args )
        case name
        when :index
          add_index( *args )
        when :foreign_key
          add_foreign_key( *args )
        else
          add_column( name, *args )
        end
      end

      # Define table using the provided block.
      def define( &block )
        fail( ArgumentError, "missing table definition block" ) unless block
        Context.new( self ).instance_eval( &block )
        self
      end

      # Dump table definition to given output.
      def dump( out = Dumper.new )
        out.dump "table #{out_name}" do
          for column in columns
            column.dump( out )
          end
          for index in indexes
            index.dump( out )
          end
          for foreign_key in foreign_keys
            foreign_key.dump( out )
          end
        end
      end

    end

    # Schema options.
    attr_reader :opts

    # Create new schema.
    def initialize( opts = {} )
      @tables = {}
      @aliases = {}
      @defaults = {}
      @callbacks = {}
      @opts = self.class.default_options.merge(opts)
    end

    # Get all tables.
    def tables
      @tables.values
    end

    # Get names of all tables.
    def table_names
      @tables.keys
    end

    # Get tables with given names.
    def named_tables( names )
      @tables.values_at( *names )
    end

    # Add table with given name, optionally defined with provided block.
    def add_table( name, &block )
      name = name.to_sym
      fail( ArgumentError, "table #{name} is already defined" ) if @tables[ name ]
      @tables[ name ] = table = Table.new( self, name )
      table.define( &block ) if block
      table
    end
    alias table add_table

    # Helper for creating join tables conveniently.
    # It is equivalent to the following:
    #   add_table name do
    #     foreign_key id_left, table_left
    #     foreign_key id_right, table_right
    #     primary_key [id_left, id_right]
    #     unique [id_right, id_left]
    #   end
    # In case a block is provided, it is used to further extend the table defined.
    def add_join_table( id_left, table_left, id_right, table_right, name = nil, &block )
      name ||= [ table_left, table_right ].sort.join( '_' )
      add_table name do
        foreign_key id_left, table_left
        foreign_key id_right, table_right
        primary_key [ id_left, id_right ]
        unique [ id_right, id_left ]
        instance_eval &block if block
      end
    end
    alias join_table add_join_table

    # Set default options for given statement used in +add_table+ blocks.
    # It uses the following arguments:
    # +name+:: The name of the statement, like +:primary_key+ or +:String+.
    #          The special name +:global+ may be used to set default options for any statement.
    # +alias+:: Optional real statement to use instead of +name+, like +:String+ instead of +:Text+.
    # +args+:: Hash containing the default options for +name+.
    # +block+:: Optional block which may further modify the options.
    #
    # If a block is provided, it is invoked with the following arguments:
    # +opts+:: The trailing options passed to given statement, to be modified as necessary.
    # +args+:: Any leading arguments passed to given statement, as readonly context.
    # +table+:: The name of the currently defined table, as readonly context.
    #
    # The final options for each statement are created in the following
    # order: +:global+ options, extended with +:null+ set to +true+ in case of ? syntax,
    # merged with options for +name+ (without ?), modified by the optional +block+
    # callback, and merged with the original options used with the statement.
    #
    # Also note that the defaults are applied in the instant the +table+ block is evaluated,
    # so it is eventually possible (though not necessarily recommended) to change them in between.
    def set_defaults( name, *args, &block )
      @aliases[ name ] = args.shift if args.first.is_a? Symbol
      @defaults[ name ] = args.pop if args.last.is_a? Hash
      @callbacks[ name ] = block
      fail( ArgumentError, "invalid defaults for #{name}" ) unless args.empty?
      self
    end

    # Clear defaults and aliases for given statement.
    def clear_defaults( name )
      @aliases.delete( name )
      @defaults.delete( name )
      @callbacks.delete( name )
      self
    end

    # Get default options for given statement.
    def get_defaults( name )
      @defaults[ name ] || {}
    end

    # Set standard defaults and aliases for often used types.
    #
    # The current set of defaults is as follows:
    #
    #   :global, :null => false
    #
    #   :Bool, :TrueClass
    #   :True, :TrueClass, :default => true
    #   :False, :TrueClass, :default => false
    #   :Signed, :integer, :unsigned => false
    #   :Unsigned, :integer, :unsigned => true
    #   :Text, :String, :text => true
    #   :Time, :timestamp, :default => '0000-00-00 00:00:00'
    #   :Time?, :timestamp, :default => nil
    #
    #   :unique, :index, :unique => true
    #
    #   :primary_key, :type => :integer, :unsigned => false
    #   :foreign_key, :key => :id, :type => :integer, :unsigned => false
    #
    # If the +unsigned_keys+ option is set to true, the keys
    # are set up to use unsigned integers instead.
    def set_standard_defaults( opts = self.opts )

      # We set NOT NULL on everything by default, but note the ?
      # syntax (like Text?) which declares the column as NULL.

      set_defaults :global, :null => false

      # We also like our keys unsigned, so we allow setting that, too.
      # Unfortunately, :unsigned currently works only with :integer,
      # not the default :Integer, and :integer can't be specified for compound keys,
      # so we have to use the callback to set the type only at correct times.
      # Furthermore, Postgres's autoincrementing serials only work with Integer,
      # so we set the type only as long as the unsigned keys are not requested.

      unsigned_keys = !! opts[ :unsigned_keys ]

      set_defaults :primary_key, :unsigned => unsigned_keys do |opts,args,table|
        opts[ :type ] ||= :integer unless args.first.is_a? Array or not opts[ :unsigned ]
      end
      set_defaults :foreign_key, :key => :id, :unsigned => unsigned_keys do |opts,args,table|
        opts[ :type ] ||= :integer unless args.first.is_a? Array or not opts[ :unsigned ]
      end

      # Save some typing for unique indexes.

      set_defaults :unique, :index, :unique => true

      # Type shortcuts we use frequently.

      set_defaults :Bool, :TrueClass
      set_defaults :True, :TrueClass, :default => true
      set_defaults :False, :TrueClass, :default => false

      set_defaults :Signed, :integer, :unsigned => false
      set_defaults :Unsigned, :integer, :unsigned => true

      set_defaults :Text, :String, :text => true

      # We want times to be stored as 4 byte timestamps, however
      # we have to be careful to turn off the MySQL autoupdate behavior.
      # That's why we have to set defaults explicitly.

      set_defaults :Time, :timestamp, :default => ZERO_TIME
      set_defaults :Time?, :timestamp, :default => nil

      self
    end

    # Apply default options to given +add_table+ block statement.
    # See +set_defaults+ for detailed explanation.
    def apply_defaults( table_name, name, *args )
      opts = {}
      opts.merge!( get_defaults( :global ) )

      if name[ -1 ] == '?'
        opts[ :null ] = true
        original_name = name
        name = name[ 0..-2 ].to_sym
      end

      opts.merge!( get_defaults( name ) )
      opts.merge!( get_defaults( original_name ) ) if original_name

      if callback = @callbacks[ name ]
        callback.call( opts, args, table_name )
      end

      opts.merge!( args.pop ) if args.last.is_a? Hash
      args << opts unless opts.empty?

      [ ( @aliases[ name ] || name ), *args ]
    end

    # Dump table definition to given output.
    def dump( out = Dumper.new )
      for table in tables
        table.dump( out )
      end
      out
    end

    # Define schema with the provided block.
    def define( &block )
      fail( ArgumentError, "missing schema block" ) unless block
      set_standard_defaults unless opts[ :use_defaults ] == false
      instance_eval &block
      self
    end

    class << self

      # Mutex protecting access to thread sensitive variables.
      LOCK = Mutex.new

      # Get default schema options.
      def default_options
        sync{ @opts || {} }
      end

      # Set default schema options.
      def default_options=( opts )
        sync{ @opts = opts.nil? ? nil : opts.dup }
      end
      alias set_default_options default_options=

      # Define schema with provided block.
      def define( opts = {}, &block )
        set_schema( new( opts ).define( &block ) )
      end

      # Load schema from given file.
      def load( name, opts = {} )
        name = File.expand_path( name )
        sync do
          get_schema do
            with_options( opts ) do
              Kernel.load( name )
            end
          end
        end
      end

      private

      # Serialize access to thread sensitive variables.
      def sync( &block )
        LOCK.synchronize &block
      rescue ThreadError
        yield
      end

      # Store given schema for later if requested.
      def set_schema( schema )
        sync{ @schema = schema if @schema == self }
        schema
      end

      # Execute given block and return stored schema.
      def get_schema
        @schema = self
        yield
        @schema unless @schema == self
      ensure
        @schema = nil
      end

      # Execute block with given options.
      def with_options( opts )
        saved, @opts = @opts, default_options.merge(opts)
        yield
      ensure
        @opts = saved
      end

    end

  end

end

# EOF #
