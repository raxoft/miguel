# Migration test.

Miguel::Schema.define do

  table :a do
    Integer :a
  end

  table :b do
    primary_key :id
    String :t
    Unsigned? :u
    Signed :s
  end

end

# EOF #
