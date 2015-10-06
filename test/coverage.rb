# Enable coverage testing in external command.

require 'simplecov'
SimpleCov.start do
  command_name "#{$PROGRAM_NAME} #{ARGV.join( ' ' ).gsub( %r[/tmp/\S+-], '/tmp/tempfile-')}"
  formatter SimpleCov::Formatter::SimpleFormatter
end

# EOF #
