# Gem specification.

require File.expand_path( '../lib/miguel/version', __FILE__ )

Gem::Specification.new do |s|
  s.name        = 'miguel'
  s.version     = Miguel::VERSION + '.pre2'
  s.summary     = 'Database migrator and migration generator for Sequel.'
  s.description = <<EOT
This gem makes it easy to create and maintain an up-to-date database schema
and apply it to the database as needed by the means of standard Sequel migrations.
EOT

  s.author      = 'Patrik Rak'
  s.email       = 'patrik@raxoft.cz'
  s.homepage    = 'http://rubygems.org/gems/miguel'
  s.license     = 'MIT'

  s.files       = `git ls-files`.split( "\n" )
  s.executables = `git ls-files -- bin/*`.split( "\n" ).map{ |f| File.basename( f ) }

  s.required_ruby_version = '>= 1.9.3'
  s.add_runtime_dependency 'sequel', '~> 4.0'
  s.add_development_dependency 'bacon', '~> 1.2'
end

# EOF #
