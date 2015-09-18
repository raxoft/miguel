# Simple schema.

Miguel::Schema.define do

  table :items do
    primary_key :id
    String :name
    foreign_key :parent_id, :items
    timestamps
    unique :name
    index :parent_id
  end

end

# EOF #
