# Test helper.

# Test coverage if enabled.

def jruby?
  defined?( RUBY_ENGINE ) and RUBY_ENGINE == 'jruby'
end

begin
  require 'codeclimate-test-reporter'
  ENV[ 'COVERAGE' ] = 'on'
rescue LoadError
end unless jruby?

if ENV[ 'COVERAGE' ]
  require 'simplecov'
  SimpleCov.start do
    add_filter 'bundler'
  end
end

# Setup helpers.

DATA_DIR = File.expand_path( "#{__FILE__}/../data" )

SEQ_COUNT = Dir[ "#{DATA_DIR}/seq_*.rb" ].count

class Bacon::Context

  def database_config
    jruby? ? 'jruby.yml' : 'db.yml'
  end

  def data( name )
    "#{DATA_DIR}/#{name}"
  end

  def lines( s )
    s.to_s.lines.map.with_index{ |l, i| "#{i}:#{l.strip}" } << :EOF
  end

  def match( a, b )
    for a, b in lines( a ).zip( lines( b ) )
      a.should == b
    end
  end

end

# EOF #
