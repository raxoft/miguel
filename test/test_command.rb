# Test Command.

require_relative 'helper'
require 'miguel/command'

require 'open3'
require 'tempfile'

describe Miguel::Command do

  EXCEPTION_SCHEMA = <<-EOT
    Miguel::Schema.define do
      raise NotImplementedError
    end
  EOT

  def match_file( data, name )
    match( data, File.read( data( name ) ) )
  end

  def with_tempfile( content = nil, extension = 'rb' )
    f = Tempfile.new( [ 'miguel', ".#{extension}" ] )
    if content
      f.write( content )
      f.flush
      f.rewind
    end
    yield f.path
  ensure
    f.close
    f.unlink
  end

  def run( *args )
    out = err = nil
    Open3.popen3( 'ruby', 'bin/miguel', *args ) do |i, o, e, t|
      yield i if block_given?
      i.close
      out = o.read
      err = e.read
    end
    [ out, err ]
  end

  def test( *args )
    out, err = run( *args )
    err.should.be.empty
    out
  end

  should 'provide help' do
    test( '--help' ).should.match /Show this message/
  end

  should 'show version' do
    test( '--version' ).should.match /\Amiguel #{Miguel::VERSION}\Z/
  end

  should 'show schema' do
    out = test( 'show', data( 'schema.rb' ) )
    match_file( out, 'schema.txt' )
  end

  should 'show schema changes' do
    out = test( 'dump', data( 'schema.rb' ) )
    match_file( out, 'schema_bare.txt' )
  end

  should 'show schema changes in various formats' do
    for format in %w[ bare change full ]
      out = test( 'dump', '--migration', format, data( 'schema.rb' ) )
      match_file( out, "schema_#{format}.txt" )
    end
  end

  should 'show changes needed to remove schema' do
    out = test( 'down', data( 'schema.rb' ) )
    match_file( out, 'schema_down.txt' )
  end

  should 'show changes needed to migrate from one schema to another' do
    with_tempfile( nil, 'db' ) do |path|
      schema = "sqlite://#{path}"
      SEQ_COUNT.times do |i|
        new_schema = data( "seq_#{i}.rb" )
        out = test( 'diff', '-m', 'full', schema, new_schema )
        match_file( out, "seq_#{i}.txt" )
        schema = new_schema
      end
    end
  end

  should 'apply schema to the database' do
    test( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ), '--force' ).should.not.be.empty
    test( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ), '--force' ).should.match /\ANo changes are necessary\.\Z/
  end

  should 'be able to clear the entire database' do
    test( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ), '--force' )
    test( 'clear', '--env', 'mysql', data( 'db.yml' ), '--force' ).should.not.be.empty
    test( 'clear', '--env', 'mysql', data( 'db.yml' ), '--force' ).should.match /\ANo changes are necessary\.\Z/
  end

  should 'require confirmation before changing the database' do
    out, err = run( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ) )
    out.should.match /^Confirm \(yes or no\)\?/
    err.should.match /\AOK, aborting\.\Z/

    out, err = run( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ) ) do |input|
      input.write 'blah'
    end
    out.should.match /^Confirm \(yes or no\)\?/
    out.should.match /Please answer 'yes' or 'no'\.$/
    err.should.match /\AOK, aborting\.\Z/

    out, err = run( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ) ) do |input|
      input.write 'no'
    end
    out.should.match /^Confirm \(yes or no\)\?/
    out.should.not.match /Please answer 'yes' or 'no'\.$/
    err.should.match /\AOK, aborting\.\Z/

    out, err = run( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ) ) do |input|
      input.write 'yes'
    end
    out.should.match /^Confirm \(yes or no\)\?/
    out.should.match /OK, those changes were applied\./
    err.should.be.empty

    out, err = run( 'clear', '--env', 'mysql', data( 'db.yml' ) )
    out.should.match /^Confirm \(yes or no\)\?/
    err.should.match /\AOK, aborting\.\Z/

    out, err = run( 'clear', '--env', 'mysql', data( 'db.yml' ) ) do |input|
      input.write 'yes'
    end
    out.should.match /^Confirm \(yes or no\)\?/
    out.should.match /OK, those changes were applied\./
    err.should.be.empty
  end

  should 'show no changes when told so' do
    test( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ), '--force', '--quiet' ).should.be.empty
    test( 'apply', '--env', 'mysql', data( 'db.yml' ), data( 'schema.rb' ), '--force', '--quiet' ).should.be.empty
    test( 'clear', '--env', 'mysql', data( 'db.yml' ), '--force', '--quiet' ).should.be.empty
    test( 'clear', '--env', 'mysql', data( 'db.yml' ), '--force', '--quiet' ).should.be.empty
  end

  should 'log SQL commands to stdout when requested' do
    test( 'show', '--env', 'mysql', data( 'db.yml' ), '--echo' ).should.match /SHOW FULL TABLES/
  end

  should 'log SQL commands to given file when requested' do
    with_tempfile do |path|
      test( 'show', '--env', 'mysql', data( 'db.yml' ), '--log', path )
      File.read( path ).should.match /SHOW FULL TABLES/
    end
  end

  should 'report errors in loaded schema' do
    with_tempfile( EXCEPTION_SCHEMA ) do |path|
      out, err = run( 'show', path )
      out.should.be.empty
      err.should.match /NotImplementedError: NotImplementedError/
      err.should.not.match /bin\/miguel/
    end
  end

  should 'show full trace when requested' do
    with_tempfile( EXCEPTION_SCHEMA ) do |path|
      out, err = run( 'show', path, '--trace' )
      out.should.be.empty
      err.should.match /bin\/miguel/
    end
  end

  should 'report invalid command' do
    out, err = run( 'blah' )
    out.should.be.empty
    err.should.match /\AInvalid command, use -h to see usage\.\Z/
  end

  should 'report invalid number of arguments' do
    out, err = run( 'show' )
    out.should.be.empty
    err.should.match /\ANot enough arguments present, use -h to see usage\.\Z/

    out, err = run( 'show', 'arg1', 'arg2' )
    out.should.be.empty
    err.should.match /\AExtra arguments present, use -h to see usage\.\Z/
  end

  should 'report invalid arguments' do
    out, err = run( 'show', '' )
    out.should.be.empty
    err.should.match /\AMissing database or schema name\.\Z/

    out, err = run( 'clear', '' )
    out.should.be.empty
    err.should.match /\AMissing database name\.\Z/

    out, err = run( 'clear', data( 'nonexistent.rb' ) )
    out.should.be.empty
    err.should.match /\ADatabase config \S+\/nonexistent\.rb not found\.\Z/
  end

  should 'report empty schema' do
    with_tempfile( '' ) do |path|
      out, err = run( 'show', path )
      out.should.be.empty
      err.should.match /\ANo schema loaded from file '\S+\.rb'\.\Z/
    end
  end

end

# EOF #
