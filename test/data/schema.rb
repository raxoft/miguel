# Test schema.

Miguel::Schema.define do

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
    DateTime :h                         # timestamp
    Time :i                             # timestamp
    Numeric :j                          # numeric
    TrueClass :k                        # boolean
    FalseClass :l                       # boolean
  end

  table :miguel_types do
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
    Time :t
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
    Unsigned :a
    Unsigned :b
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

  join_table :user_id, :users, :simple_id, :simple

  join_table :left_id, :users, :right_id, :users, :self_join do
    timestamps
    index :create_time
  end

end

# EOF #
