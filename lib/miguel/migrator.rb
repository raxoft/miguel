# Schema migrator.

require 'miguel/schema'
require 'miguel/dumper'

module Miguel

  # Class for generating database migration from one schema to another.
  class Migrator

    private

    # Separate items in before and after arrays into old items, same items and new items.
    def separate( before, after )
      # Note that we have to use ==, so we can't use & and - operators which use eql?.
      same = after.select{ |x| before.find{ |y| x == y } }
      [
        before.reject{ |x| same.find{ |y| x == y } },
        same,
        after.reject{ |x| same.find{ |y| x == y } },
      ]
    end

    # Iterate over matching pairs of named items.
    def each_pair( name, from_items, to_items )
      for from, to in from_items.zip( to_items )
        fail "invalid #{name} pair #{from.name} -> #{to.name}" unless from.name == to.name
        yield from, to
      end
    end

    # Convert foreign keys from given tables into [ table name, foreign key ] pairs for easier comparison.
    def prepare_keys( tables )
      result = []
      for table in tables
        for key in table.foreign_keys
          result << [ table.name, key ]
        end
      end
      result
    end

    # Convert [ table name, foreign key ] pairs into hash of foreign keys per table.
    def split_keys( table_keys )
      result = {}
      for name, key in table_keys
        ( result[ name ] ||= [] ) << key
      end
      result
    end

    # Generate code for altering given foreign keys.
    def dump_foreign_keys( out, table_keys, &block )
      for name, keys in split_keys( table_keys )
        out.dump "alter_table #{name.inspect}" do
          keys.each &block
        end
      end
    end

    # Generate code for adding given foreign keys.
    def dump_add_foreign_keys( out, table_keys )
      dump_foreign_keys( out, table_keys ) do |key|
        out << "add_foreign_key #{key.out_columns}, #{key.out_table_name}#{key.out_canonic_opts}"
      end
    end

    # Generate code for dropping given foreign keys.
    def dump_drop_foreign_keys( out, table_keys )
      dump_foreign_keys( out, table_keys ) do |key|
        out << "drop_foreign_key #{key.out_columns} # #{key.out_table_name}#{key.out_canonic_opts}"
      end
    end

    # Generate code for adding given tables.
    def dump_add_tables( out, tables )
      for table in tables
        out.dump "create_table #{table.out_name}" do
          for column in table.columns
            column.dump( out )
          end
          for index in table.indexes
            index.dump( out )
          end
          # No foreign keys here - those are added in a separate pass later.
        end
      end
    end

    # Generate code for dropping given tables.
    def dump_drop_tables( out, tables )
      for table in tables
        out << "drop_table #{table.out_name}"
      end
    end

    # Generate code for dropping given indexes.
    def dump_drop_indexes( out, indexes )
      for index in indexes
        out << "drop_index #{index.out_columns}#{index.out_canonic_opts(' # ')}"
      end
    end

    # Generate code for adding given indexes.
    def dump_add_indexes( out, indexes )
      for index in indexes
        out << "add_index #{index.out_columns}#{index.out_canonic_opts}"
      end
    end

    # Generate code for dropping given columns.
    def dump_drop_columns( out, columns )
      for column in columns
        if column.primary_key_constraint?
          out << "drop_constraint #{column.out_name}, :type => :primary_key#{column.out_opts(' # ')}"
        else
          out << "drop_column #{column.out_name} # #{column.out_type}#{column.out_opts}"
        end
      end
    end

    # Generate code for adding given columns.
    def dump_add_columns( out, columns )
      for column in columns
        if column.type == :primary_key
          out << "add_primary_key #{column.out_name}#{column.out_opts}"
        else
          out << "add_column #{column.out_name}, #{column.out_type}#{column.out_opts}"
        end
      end
    end

    # Generate code for altering given column.
    def dump_alter_column( out, from, to )
      if from.allow_null != to.allow_null && to.allow_null
        out << "set_column_allow_null #{to.out_name}"
      end
      if from.canonic_type != to.canonic_type || from.type_opts != to.type_opts
        out << "set_column_type #{to.out_name}, #{to.out_type}#{to.out_opts}"
      end
      if from.default != to.default
        out << "set_column_default #{to.out_name}, #{to.out_default}"
      end
      if from.allow_null != to.allow_null && ! to.allow_null
        out << "set_column_not_null #{to.out_name}"
      end
    end

    # Generate code for altering given columns.
    def dump_alter_columns( out, from_columns, to_columns )
      each_pair( :column, from_columns, to_columns ) do |from, to|
        dump_alter_column( out, from, to )
      end
    end

    # Generate code for altering given table.
    def dump_alter_table( out, from, to )
      old_indexes, same_indexes, new_indexes = separate( from.indexes, to.indexes )

      from_names = from.column_names
      to_names = to.column_names

      old_names, same_names, new_names = separate( from_names, to_names )

      old_columns = from.named_columns( old_names )
      new_columns = to.named_columns( new_names )

      from_columns = from.named_columns( same_names )
      to_columns = to.named_columns( same_names )

      from_columns, same_columns, to_columns = separate( from_columns, to_columns )

      return if [ old_indexes, new_indexes, old_columns, new_columns, to_columns ].all?{ |x| x.empty? }

      out.dump "alter_table #{to.out_name}" do
        dump_drop_indexes( out, old_indexes )
        dump_drop_columns( out, old_columns )
        dump_alter_columns( out, from_columns, to_columns )
        dump_add_columns( out, new_columns )
        dump_add_indexes( out, new_indexes )
      end
    end

    # Generate code for altering given tables.
    def dump_alter_tables( out, from_tables, to_tables )
      each_pair( :table, from_tables, to_tables ) do |from, to|
        dump_alter_table( out, from, to )
      end
    end

    public

    # Generate code for changing one schema to another.
    def changes( from, to, out = Dumper.new )
      from_keys = prepare_keys( from.tables )
      to_keys = prepare_keys( to.tables )

      old_keys, same_keys, new_keys = separate( from_keys, to_keys )

      from_names = from.table_names
      to_names = to.table_names

      old_names, same_names, new_names = separate( from_names, to_names )

      old_tables = from.named_tables( old_names )
      new_tables = to.named_tables( new_names )

      from_tables = from.named_tables( same_names )
      to_tables = to.named_tables( same_names )

      dump_drop_foreign_keys( out, old_keys )
      dump_drop_tables( out, old_tables )
      dump_alter_tables( out, from_tables, to_tables )
      dump_add_tables( out, new_tables )
      dump_add_foreign_keys( out, new_keys )

      out
    end

    # Generate one way Sequel migration.
    def change_migration( from, to, out = Dumper.new )
      out.dump "Sequel.migration" do
        out.dump "change" do
          changes( from, to, out )
        end
      end
    end

    # Generate both ways Sequel migration.
    def full_migration( from, to, out = Dumper.new )
      out.dump "Sequel.migration" do
        out.dump "up" do
          changes( from, to, out )
        end
        out.dump "down" do
          changes( to, from, out )
        end
      end
    end

    alias migration full_migration

  end

end

# EOF #
