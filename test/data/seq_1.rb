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
  end

  table :c do
    primary_key :id
    String? :s
  end

  table :d do
    Integer :a
    Integer :b
  end

end

# EOF #
