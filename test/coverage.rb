# Enable coverage testing in external command.

require 'simplecov'
SimpleCov.start do
  command_name ENV[ 'COVERAGE_COMMAND_NAME' ] || "#{$PROGRAM_NAME} #{ARGV.join( ' ' )}"
  formatter SimpleCov::Formatter::SimpleFormatter
end

# EOF #
