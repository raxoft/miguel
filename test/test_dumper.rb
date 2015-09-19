# Test Dumper.

require_relative 'helper'
require 'miguel/dumper'

describe Miguel::Dumper do

  should 'collect dumped lines' do
    d = Miguel::Dumper.new
    d.dump "a"
    d << "b"
    d.dump "c"
    d << "d"
    d.text.should == "a\nb\nc\nd\n"
  end

  should 'support nesting' do
    d = Miguel::Dumper.new
    d.dump "test" do
      d.dump "row" do
        d << "x"
        d << "y"
      end
      d.dump "foo" do
        d << "bar"
      end
    end
    d.text.should == <<EOT
test do
  row do
    x
    y
  end
  foo do
    bar
  end
end
EOT
  end

  should 'support text interpolation' do
    d = Miguel::Dumper.new
    d << "abc"
    d << "xyz"
    d.text.should == d.to_s
    d.text.should == "#{d}"
  end

  should 'accept nonstring arguments' do
    d = Miguel::Dumper.new
    d << 123
    d << 0.5
    d << :test
    d.text.should == "123\n0.5\ntest\n"
  end

  should 'support chaining' do
    d = Miguel::Dumper.new
    d.dump( "x" ).should == d
    ( d << "y" << "z" ).should == d
    d.text.should == "x\ny\nz\n"
  end

  should 'support custom buffer' do
    a = []
    d = Miguel::Dumper.new( a )
    d << "xyz"
    d << "abc"
    a.should == [ "xyz\n", "abc\n" ]
    d.text.should == "xyz\nabc\n"
  end

  should 'support configurable indentation' do
    d = Miguel::Dumper.new( [], 4 )
    d.dump "a" do
      d.dump "b" do
        d << "c"
      end
    end
    d.text.should == <<EOT
a do
    b do
        c
    end
end
EOT
  end

end

# EOF #
