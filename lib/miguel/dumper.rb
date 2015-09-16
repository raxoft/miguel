# Simple dumper.

module Miguel

  # Class for dumping indented code blocks.
  class Dumper

    # Create new dumper.
    def initialize( out = [], step = 2 )
      @out = out
      @indent = 0
      @step = step
    end

    # Get all output gathered so far as a string.
    def text
      @out.join
    end

    alias to_s text

    # Append given line/block to the output.
    #
    # If block is given, it is automatically enclosed between do/end keywords
    # and anything dumped within it is automatically indented.
    def dump( line )
      if block_given?
        dump "#{line} do"
        @indent += @step
        yield
        @indent -= @step
        dump "end"
      else
        @out << "#{' ' * @indent}#{line}\n"
      end
      self
    end

    alias << dump

  end

end

# EOF #
