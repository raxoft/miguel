# Command line driver.

require 'miguel'
require 'optparse'

module Miguel

  # Miguel command line interface.
  class Command

    attr_reader :env, :format, :loggers, :force, :quiet, :trace

    # Initialize the command options.
    def init
      @env = nil
      @format = nil
      @loggers = []
      @force = nil
      @quiet = nil
      @trace = nil
    end

    # Run the command.
    def run( args )
      args = args.dup
      init
      OptionParser.new( &method( :set_opts ) ).parse!( args )
      execute( args )
      exit 0
    rescue Exception => e
      raise if trace or e.is_a?( SystemExit )
      $stderr.print "#{e.class}: " unless e.is_a?( RuntimeError )
      $stderr.puts e.message
      exit 1
    end

    private

    # Set the command options.
    def set_opts( opts )
      opts.banner = "Miguel: The Database Migrator and Migration Generator for Sequel"
      opts.define_head "Usage: miguel [options] <command> <db|schema> [db|schema]"
      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  miguel show mysql://localhost/main"
      opts.separator "  miguel dump schema.rb"
      opts.separator "  miguel diff db.yml test.yml"
      opts.separator "  miguel apply db.yml schema.rb"
      opts.separator ""
      opts.separator "Commands:"
      opts.separator "  show <db|schema>                   Show schema of given database or schema file"
      opts.separator "  dump <db|schema>                   Dump migration which creates given schema"
      opts.separator "  down <db|schema>                   Dump migration which reverses given schema"
      opts.separator "  diff <db|schema> <db|schema>       Dump migration needed to migrate to the second schema"
      opts.separator "  apply <db> <db|schema>             Apply given schema to the database"
      opts.separator "  clear <db>                         Drop all tables in given database"
      opts.separator ""
      opts.separator "Options:"

      opts.on_tail( '-h', '-?', '--help', 'Show this message' ) do
        puts opts
        exit
      end

      opts.on( '-e', '--env <env>', 'Use given environment config for database(s)' ) do |v|
        @env = v
      end

      opts.on( '-E', '--echo', 'Echo SQL statements' ) do
        require 'logger'
        @loggers << Logger.new( $stdout )
      end

      opts.on( '-f', '--force', 'Force changes to be applied without confirmation' ) do
        @force = true
      end

      opts.on( '-l', '--log <file>', 'Log SQL statements to given file' ) do |v|
        require 'logger'
        @loggers << Logger.new( v )
      end

      formats = [ :bare, :change, :full ]
      opts.on( '-m', '--migration <format>', formats, "Select format for dumped migrations (#{formats.join(', ')})" ) do |v|
        @format = v
      end

      opts.on( '-q', '--quiet', "Don't display the changes to be applied" ) do
        @quiet = true
      end

      opts.on( '-t', '--trace', 'Show full backtrace if an exception is raised' ) do
        @trace = true
      end

      opts.on_tail( '-v', '--version', 'Print version' ) do
        puts "miguel #{Miguel::VERSION}"
        exit
      end
    end

    # Execute the command itself.
    def execute( args )
      command = args.shift or fail "Missing command, use -h to see usage."
      method = "execute_#{command}"
      fail "Invalid command, use -h to see usage." unless respond_to?( method, true )
      check_args( args, method( method ).arity )
      send( method, *args )
    end

    # Execute the show command.
    def execute_show( name )
      schema = get_schema( name )
      print schema.dump
    end

    # Execute the dump command.
    def execute_dump( name )
      schema = get_schema( name )
      show_changes( Schema.new, schema )
    end

    # Execute the down command.
    def execute_down( name )
      schema = get_schema( name )
      show_changes( schema, Schema.new )
    end

    # Execute the diff command.
    def execute_diff( old_name, new_name )
      old_schema = get_schema( old_name )
      new_schema = get_schema( new_name )
      show_changes( old_schema, new_schema )
    end

    # Execute the apply command.
    def execute_apply( db_name, name )
      db = get_db( db_name )
      schema = get_schema( name )
      apply_schema( db, schema )
    end

    # Execute the clear command.
    def execute_clear( db_name )
      db = get_db( db_name )
      apply_schema( db, Schema.new )
    end

    # Make sure the argument count is as expected.
    def check_args( args, count )
      fail "Not enough arguments present, use -h to see usage." if args.count < count
      fail "Extra arguments present, use -h to see usage." if args.count > count
    end

    # Import schema from given database.
    def import_schema( db )
      Importer.new( db ).schema
    end

    # Get schema from given schema file or database.
    def get_schema( name )
      schema = if name.nil? or name.empty?
        fail "Missing database or schema name."
      elsif File.exist?( name ) and name =~ /\.rb\b/
        Schema.load( name ) or fail "No schema loaded from file '#{name}'."
      else
        db = get_db( name )
        import_schema( db )
      end
      schema
    end

    # Connect to given database.
    def get_db( name )
      db = if name.nil? or name.empty?
        fail "Missing database name."
      elsif File.exist?( name )
        config = load_db_config( name )
        Sequel.connect( config )
      elsif name =~ /:/
        Sequel.connect( name )
      else
        fail "Database config #{name} not found."
      end
      db.loggers = loggers
      db
    end

    # Load database config from given file.
    def load_db_config( name )
      require 'yaml'
      config = YAML.load_file( name )
      env = self.env || "development"
      config = config[ env ] || config[ env.to_sym ] || config
      config.keys.each{ |k| config[ k.to_sym ] = config.delete( k ) }
      config
    end

    # Show changes between the two schemas.
    def show_changes( from, to )
      m = Migrator.new
      case format
      when nil, :bare
        print m.changes( from, to )
      when :change
        print m.change_migration( from, to )
      when :full
        print m.full_migration( from, to )
      end
    end

    # Apply given schema to given database.
    def apply_schema( db, schema )
      from = import_schema( db )
      changes = Migrator.new.changes( from, schema ).to_s

      if changes.empty?
        puts "No changes are necessary." unless quiet
        return
      end

      unless quiet
        puts "These changes will be applied to the database:"
        print changes
      end

      unless force
        fail "OK, aborting." unless confirm?
      end

      db.instance_eval( changes )

      puts "OK, those changes were applied." unless quiet
    end

    # Ask the user for a confirmation.
    def confirm?
      loop do
        print "Confirm (yes or no)? "

        unless line = $stdin.gets
          puts
          puts "I take EOF as 'no'. Use --force if you want to skip the confirmation instead."
          return
        end

        case line.chomp.downcase
        when 'yes'
          return true
        when 'no'
          return false
        else
          puts "Please answer 'yes' or 'no'."
        end
      end
    end

  end

end

# EOF #
