# Migration test.

Miguel::Schema.define do

  table :a do
    primary_key :id
    Float :a
    foreign_key :fk, :c
  end

  table :b do
    primary_key :id
    Text :t
    Unsigned :u, default: 123
    Signed? :s
    timestamps
    foreign_key :fk, :a
    unique :u
    index :create_time
  end

  table :c do
    primary_key :id
    String? :s
  end

  join_table :left_id, :a, :right_id, :b

end

# EOF #
