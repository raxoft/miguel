# Test helper.

# Test coverage if enabled.

begin
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
rescue LoadError
end

# Setup helpers.

DATA_DIR = File.expand_path( "#{__FILE__}/../data" )

SEQ_COUNT = Dir[ "#{DATA_DIR}/seq_*.rb" ].count

class Bacon::Context

  def data( name )
    "#{DATA_DIR}/#{name}"
  end

end

# EOF #
