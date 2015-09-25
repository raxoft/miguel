# Test Schema.

require_relative 'helper'
require 'miguel/schema'

describe Miguel::Schema do

  after do
    Miguel::Schema.default_options = nil
  end

  def match_file( schema, name )
    match( schema.dump, File.read( data( name ) ) )
  end

  def match_schema( text, opts = {}, &block )
    schema = Miguel::Schema.new( opts ).define( &block )
    match( schema.dump, text )
  end

  should 'load and dump schema properly' do
    schema = Miguel::Schema.load( data( 'schema.rb' ) )
    match_file( schema, 'schema.txt' )
  end

  should 'allow changing default schema options temporarily' do
    schema = Miguel::Schema.load( data( 'simple.rb' ), unsigned_keys: true, mysql_timestamps: true )
    match_file( schema, 'simple_mysql.txt' )
    Miguel::Schema.new.opts.should.be.empty

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    match_file( schema, 'simple.txt' )
  end

  should 'allow changing default schema options permanently' do
    Miguel::Schema.default_options.should == {}

    Miguel::Schema.set_default_options( unsigned_keys: true, mysql_timestamps: true )
    Miguel::Schema.new( test: true ).opts.should == { unsigned_keys: true, mysql_timestamps: true, test: true }
    Miguel::Schema.default_options.should == { unsigned_keys: true, mysql_timestamps: true }

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    match_file( schema, 'simple_mysql.txt' )

    Miguel::Schema.default_options = nil
    Miguel::Schema.default_options.should == {}
    Miguel::Schema.new.opts.should.be.empty

    schema = Miguel::Schema.load( data( 'simple.rb' ) )
    match_file( schema, 'simple.txt' )
  end

  should 'support plain sequel types' do
    match_schema <<-EOT, use_defaults: false do
      table :sequel_types do
        Integer :a0
        String :a1
        String :a2, :size => 50
        String :a3, :fixed => true
        String :a4, :fixed => true, :size => 50
        String :a5, :text => true
        File :b
        Fixnum :c
        Bignum :d
        Float :e
        BigDecimal :f
        BigDecimal :f2, :size => 10
        BigDecimal :f3, :size => [10, 2]
        Date :g
        DateTime :h
        Time :i
        Time :i2, :only_time => true
        Numeric :j
        TrueClass :k
        FalseClass :l
      end
    EOT
      table :sequel_types do
        Integer :a0                         # integer
        String :a1                          # varchar(255)
        String :a2, :size=>50               # varchar(50)
        String :a3, :fixed=>true            # char(255)
        String :a4, :fixed=>true, :size=>50 # char(50)
        String :a5, :text=>true             # text
        File :b                             # blob
        Fixnum :c                           # integer
        Bignum :d                           # bigint
        Float :e                            # double precision
        BigDecimal :f                       # numeric
        BigDecimal :f2, :size=>10           # numeric(10)
        BigDecimal :f3, :size=>[10, 2]      # numeric(10, 2)
        Date :g                             # date
        DateTime :h                         # timestamp or datetime
        Time :i                             # timestamp or datetime
        Time :i2, :only_time=>true          # time
        Numeric :j                          # numeric
        TrueClass :k                        # boolean
        FalseClass :l                       # boolean
      end
    end
  end

  should 'support default miguel types' do
    match_schema <<-EOT do
      table :miguel_types do
        integer :key, :null => false, :unsigned => false
        String :string, :null => false
        String :text, :null => false, :text => true
        File :blob, :null => false
        Integer :int, :null => false
        integer :signed, :null => false, :unsigned => false
        integer :unsigned, :null => false, :unsigned => true
        Float :float, :null => false
        TrueClass :bool, :null => false
        TrueClass :true, :null => false, :default => true
        TrueClass :false, :null => false, :default => false
        timestamp :time, :null => false, :default => "2000-01-01 00:00:00"
      end
    EOT
      table :miguel_types do
        Key :key
        String :string
        Text :text
        File :blob
        Integer :int
        Signed :signed
        Unsigned :unsigned
        Float :float
        Bool :bool
        True :true
        False :false
        Time :time
      end
    end
  end

  should 'support custom types' do
    match_schema <<-EOT do
      table :custom_types do
        String :custom, :null => false, :fixed => true, :size => 3
        datetime :time, :null => false
        datetime :time2, :null => true, :default => nil
      end
    EOT
      set_defaults :Custom, :String, fixed: true, size: 3
      set_defaults :Time, :datetime
      set_defaults :Time?, :datetime, default: nil
      table :custom_types do
        Custom :custom
        Time :time
        Time? :time2
      end
    end
  end

  should 'support native types' do
    match_schema <<-EOT do
      table :native_types do
        date :date, :null => false, :default => "2000-12-31"
        time :time, :null => false, :default => "23:59:59"
        datetime :datetime, :null => false, :default => "2037-12-31 23:59:59"
        timestamp :timestamp, :null => false, :default => "1970-01-02 00:00:00"
      end
    EOT
      table :native_types do
        date :date, default: '2000-12-31'
        time :time, default: '23:59:59'
        datetime :datetime, default: '2037-12-31 23:59:59'
        timestamp :timestamp, default: '1970-01-02 00:00:00'
      end
    end
  end

  should 'support enums' do
    match_schema <<-EOT do
      table :enum do
        enum :error, :null => false, :elements => ["none", "invalid", "expired", "declined", "other"], :default => "none"
      end
    EOT
      table :enum do
        enum :error, elements: %w[ none invalid expired declined other ], default: 'none'
      end
    end
  end

  should 'support sets' do
    match_schema <<-EOT do
      table :set do
        set :permissions, :null => false, :elements => ["read", "write", "create", "delete"], :default => "read"
      end
    EOT
      table :set do
        set :permissions, elements: %w[ read write create delete ], default: 'read'
      end
    end
  end

  should 'support generic timestamps' do
    match_schema <<-EOT do
      table :timestamps do
        timestamp :t1, :null => false, :default => "2000-01-01 00:00:00"
        timestamp :t2, :null => true, :default => nil
        timestamp :create_time, :null => false, :default => "2000-01-01 00:00:00"
        timestamp :update_time, :null => false, :default => "2000-01-01 00:00:00"
      end
    EOT
      table :timestamps do
        Time :t1
        Time? :t2
        timestamps
      end
    end
  end

  should 'support MySQL timestamps' do
    match_schema <<-EOT, mysql_timestamps: true do
      table :timestamps do
        timestamp :t1, :null => false, :default => "0000-00-00 00:00:00"
        timestamp :t2, :null => true, :default => nil
        timestamp :create_time, :null => false, :default => "0000-00-00 00:00:00"
        timestamp :update_time, :null => false, :default => Sequel.lit("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")
      end
    EOT
      table :timestamps do
        Time :t1
        Time? :t2
        timestamps
      end
    end
  end

  should 'support auto-incrementing primary keys' do
    match_schema <<-EOT do
      table :pk do
        primary_key :id, :null => false, :unsigned => false
      end
    EOT
      table :pk do
        primary_key :id
      end
    end
  end

  should 'support non-incrementing primary keys' do
    match_schema <<-EOT do
      table :pk do
        integer :id, :null => false, :unsigned => false, :primary_key => true
      end
    EOT
      table :pk do
        Key :id, primary_key: true
      end
    end
  end

  should 'support compound primary keys' do
    match_schema <<-EOT do
      table :pk do
        Integer :a, :null => false
        Integer :b, :null => false
        primary_key [:a, :b], :null => false, :unsigned => false
      end
    EOT
      table :pk do
        Integer :a
        Integer :b
        primary_key [:a, :b]
      end
    end
  end

  should 'support foreign keys' do
    match_schema <<-EOT do
      table :fk do
        integer :user_id, :null => false, :key => [:id], :unsigned => false
        foreign_key [:user_id], :users, :null => false, :key => [:id], :unsigned => false
      end
    EOT
      table :fk do
        foreign_key :user_id, :users
      end
    end
  end

  should 'support reused foreign keys' do
    match_schema <<-EOT do
      table :fk do
        primary_key :user_id, :null => false, :unsigned => false
        foreign_key [:user_id], :users, :null => false, :key => [:id], :unsigned => false
      end
    EOT
      table :fk do
        primary_key :user_id
        foreign_key [:user_id], :users
      end
    end
  end

  should 'support compound foreign keys' do
    match_schema <<-EOT do
      table :fk do
        Integer :x, :null => false
        Integer :y, :null => false
        foreign_key [:x, :y], :pk, :null => false, :key => [:a, :b], :unsigned => false
      end
    EOT
      table :fk do
        Integer :x
        Integer :y
        foreign_key [:x, :y], :pk, key: [:a, :b]
      end
    end
  end

  should 'support unsigned keys' do
    match_schema <<-EOT, unsigned_keys: true do
      table :pk do
        primary_key :id, :null => false, :unsigned => true, :type => :integer
      end
      table :pk2 do
        integer :id, :null => false, :unsigned => true, :primary_key => true
      end
      table :pk3 do
        Integer :a, :null => false
        Integer :b, :null => false
        primary_key [:a, :b], :null => false, :unsigned => true
      end
      table :fk do
        integer :user_id, :null => false, :key => [:id], :unsigned => true, :type => :integer
        foreign_key [:user_id], :users, :null => false, :key => [:id], :unsigned => true, :type => :integer
      end
      table :fk2 do
        primary_key :user_id, :null => false, :unsigned => true, :type => :integer
        foreign_key [:user_id], :users, :null => false, :key => [:id], :unsigned => true
      end
      table :fk3 do
        Integer :x, :null => false
        Integer :y, :null => false
        foreign_key [:x, :y], :pk, :null => false, :key => [:a, :b], :unsigned => true
      end
    EOT
      table :pk do
        primary_key :id
      end
      table :pk2 do
        Key :id, primary_key: true
      end
      table :pk3 do
        Integer :a
        Integer :b
        primary_key [:a, :b]
      end
      table :fk do
        foreign_key :user_id, :users
      end
      table :fk2 do
        primary_key :user_id
        foreign_key [:user_id], :users
      end
      table :fk3 do
        Integer :x
        Integer :y
        foreign_key [:x, :y], :pk, key: [:a, :b]
      end
    end
  end

  should 'support indexes' do
    match_schema <<-EOT do
      table :index do
        Integer :a, :null => false
        Integer :b, :null => false
        String :s, :null => false
        index [:a], :null => false
        index [:b], :null => false, :unique => true
        index [:a, :b], :null => false
        index [:a, :b, :c], :null => false, :unique => true
      end
    EOT
      table :index do
        Integer :a
        Integer :b
        String :s
        index :a
        unique :b
        index [:a, :b]
        unique [:a, :b, :c]
      end
    end
  end

  should 'support null columns' do
    match_schema <<-EOT do
      table :null do
        String :string, :null => true
        String :text, :null => true, :text => true
        File :blob, :null => true
        Integer :int, :null => true
        integer :signed, :null => true, :unsigned => false
        integer :unsigned, :null => true, :unsigned => true
        Float :float, :null => true
        TrueClass :bool, :null => true
        TrueClass :true, :null => true, :default => true
        TrueClass :false, :null => true, :default => false
        timestamp :time, :null => true, :default => nil
        integer :user_id, :null => true, :key => [:id], :unsigned => false
        foreign_key [:user_id], :users, :null => true, :key => [:id], :unsigned => false
      end
    EOT
      table :null do
        String? :string
        Text? :text
        File? :blob
        Integer? :int
        Signed? :signed
        Unsigned? :unsigned
        Float? :float
        Bool? :bool
        True? :true
        False? :false
        Time? :time
        foreign_key? :user_id, :users
      end
    end
  end

  should 'support default values' do
    match_schema <<-EOT do
      table :defaults do
        String :string, :null => false, :default => "abc"
        Integer :int, :null => false, :default => 10
        integer :signed, :null => false, :unsigned => false, :default => -1
        integer :unsigned, :null => false, :unsigned => true, :default => 1000
        Float :float, :null => false, :default => 3.14
        TrueClass :bool, :null => false, :default => true
        timestamp :time, :null => false, :default => "2037-12-31 23:59:59"
      end
    EOT
      table :defaults do
        String :string, default: 'abc'
        Integer :int, default: 10
        Signed :signed, default: -1
        Unsigned :unsigned, default: 1000
        Float :float, default: 3.14
        Bool :bool, default: true
        Time :time, default: '2037-12-31 23:59:59'
      end
    end
  end

  should 'support arbitrary types and options' do
    match_schema <<-EOT do
      table :whatever do
        Foo :foo, :null => false, :abc => :xyz, :data => ["x", 2, 3.5, :bar], :opts => {:none => true}
      end
    EOT
      table :whatever do
        Foo :foo, abc: :xyz, data: ["x", 2, 3.5, :bar], opts: { none: true }
      end
    end
  end

  should 'create join tables' do
    match_schema <<-EOT do
      table :left_right do
        integer :left_id, :null => false, :key => [:id], :unsigned => false
        integer :right_id, :null => false, :key => [:id], :unsigned => false
        primary_key [:left_id, :right_id], :null => false, :unsigned => false
        index [:right_id, :left_id], :null => false, :unique => true
        foreign_key [:left_id], :left, :null => false, :key => [:id], :unsigned => false
        foreign_key [:right_id], :right, :null => false, :key => [:id], :unsigned => false
      end
    EOT
      join_table :left_id, :left, :right_id, :right
    end
  end

  should 'create join tables with custom name' do
    match_schema <<-EOT do
      table :custom_name do
        integer :left_id, :null => false, :key => [:id], :unsigned => false
        integer :right_id, :null => false, :key => [:id], :unsigned => false
        primary_key [:left_id, :right_id], :null => false, :unsigned => false
        index [:right_id, :left_id], :null => false, :unique => true
        foreign_key [:left_id], :left, :null => false, :key => [:id], :unsigned => false
        foreign_key [:right_id], :right, :null => false, :key => [:id], :unsigned => false
      end
    EOT
      join_table :left_id, :left, :right_id, :right, :custom_name
    end
  end

  should 'create join tables with additional columns' do
    match_schema <<-EOT do
      table :left_right do
        integer :left_id, :null => false, :key => [:id], :unsigned => false
        integer :right_id, :null => false, :key => [:id], :unsigned => false
        primary_key [:left_id, :right_id], :null => false, :unsigned => false
        String :name, :null => false
        index [:right_id, :left_id], :null => false, :unique => true
        foreign_key [:left_id], :left, :null => false, :key => [:id], :unsigned => false
        foreign_key [:right_id], :right, :null => false, :key => [:id], :unsigned => false
      end
    EOT
      join_table :left_id, :left, :right_id, :right do
        String :name
      end
    end
  end

end

# EOF #
