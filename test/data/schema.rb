# Test schema.

Miguel::Schema.define( use_defaults: false ) do

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
    #DateTime :h                        # timestamp or datetime
    #Time :i                            # timestamp or datetime
    Time :i2, :only_time=>true          # time
    Numeric :j                          # numeric
    TrueClass :k                        # boolean
    FalseClass :l                       # boolean
  end

  set_standard_defaults
  set_defaults :Custom, :String, fixed: true, size: 3

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
    Custom :custom
  end

  table :native_types do
    date :date, default: '2000-12-31'
    time :time, default: '23:59:59'
    datetime :datetime, default: '2037-12-31 23:59:59'
    timestamp :timestamp, default: '1970-01-02 00:00:00'
  end

  table :timestamps do
    Time :t1
    Time? :t2
    timestamps
  end

  table :users do
    primary_key :id
    String :name
    unique :name
  end

  table :simple do
    primary_key :id
    foreign_key :user_id, :users
    index :user_id
  end

  table :reuse do
    primary_key :user_id
    foreign_key [:user_id], :users
  end

  table :compound do
    Integer :a
    Integer :b
    primary_key [:a, :b]
    foreign_key [:b, :a], :compound, key: [:a, :b]
    String :c
    Signed :d
    unique [:a, :c]
    index [:b, :c, :d]
    index [:b, :a]
  end

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
    Time? :t
    foreign_key? :user_id, :users
  end

  table :defaults do
    String :string, default: 'abc'
    Integer :int, default: 10
    Signed :signed, default: -1
    Unsigned :unsigned, default: 1000
    Float :float, default: 3.14
    Bool :bool, default: true
    Time :time, default: '2037-12-31 23:59:59'
  end

  join_table :user_id, :users, :simple_id, :simple

  join_table :left_id, :users, :right_id, :users, :self_join do
    timestamps
    index :create_time
  end

end

# EOF #
