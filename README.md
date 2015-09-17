# Miguel

[![Gem Version](https://img.shields.io/gem/v/miguel.svg)](http://rubygems.org/gems/miguel) [![Build Status](https://img.shields.io/travis/raxoft/miguel.svg?branch=master)](http://travis-ci.org/raxoft/miguel) [![Dependency Status](https://img.shields.io/gemnasium/raxoft/miguel.svg)](https://gemnasium.com/raxoft/miguel) [![Code Climate](https://img.shields.io/codeclimate/github/raxoft/miguel.svg)](https://codeclimate.com/github/raxoft/miguel) [![Coverage](https://img.shields.io/codeclimate/coverage/github/raxoft/miguel.svg)](https://codeclimate.com/github/raxoft/miguel)

Miguel is a tool for sane management of database schemas. It aims to help with these goals:

* Have just one up-to-date description of the desired database schema using a concise DSL.
* Apply that schema to the database anytime, no matter how either may have diverged.
* Adjust and repeat as often as needed.

To achieve this, it provides the following features:

* [Sequel](http://sequel.jeremyevans.net/)-like DSL for schema description with some enhancements.
* Load schema from given description file or from given database.
* Show changes necessary to turn one schema into another.
* Render those changes as Sequel's change or up/down migrations.
* Alternatively apply those changes directly to the database.

## Describing the schema

The schema is described using a DSL similar to Sequel's
[standard schema syntax](http://sequel.jeremyevans.net/rdoc/files/doc/schema_modification_rdoc.html).
It looks like this:

``` ruby
# Example schema for Miguel.
Miguel::Schema.define do

  # The user, the core of every web site.

  table :users do
    primary_key :id

    # The login id, usually user email address.
    String :login
    # The encrypted password.
    String :password

    # First name(s).
    String :first_name
    # Last name(s).
    String :last_name

    # Arbitrary JSON encoded info.
    Text? :info

    timestamps

    unique :login
    index :first_name
    index :last_name
    index :create_time
  end

  # User's emails, as every user can have multiple emails.

  table :user_emails do
    primary_key :id

    # The email address itself.
    String :email
    # To which user does the email belong.
    foreign_key :user_id, :users

    # Flag set when this email is verified.
    False :verified
    # Flag set when this email is marked as their primary email by the user.
    False :primary

    timestamps

    unique :email
    index :user_id
    index :create_time
  end

  # User's profile, collecting various info about the user.

  table :user_profiles do
    primary_key :user_id
    foreign_key [:user_id], :users

    String? :company
    String? :street
    String? :city
    String? :state
    String? :country
    String? :zip
    String? :phone
    String? :fax
    String? :url

    index :country
    index :state
  end

  # User's followers.

  join_table :user_id, :users, :follower_id, :users, :user_followers

end
```

One enhancement is that it allows you to define `NULL` columns simply by adding `?` to the type name.
Anything else is implicitly `NOT NULL`, which is a really wise default.

Another enhancement is that it allows you to set defaults and
define custom shortcuts for types which you use frequently.
See documentation of the `set_defaults` method for details.
The preset defaults are like this:

``` ruby
set_defaults :global, :null => false
set_defaults :primary_key, :type => :integer, :unsigned => true
set_defaults :foreign_key, :key => :id, :type => :integer, :unsigned => true
set_defaults :unique, :index, :unique => true
set_defaults :Bool, :TrueClass
set_defaults :True, :TrueClass, :default => true
set_defaults :False, :TrueClass, :default => false
set_defaults :Signed, :integer, :unsigned => false
set_defaults :Unsigned, :integer, :unsigned => true
set_defaults :Text, :String, :text => true
set_defaults :Time, :timestamp, :default => 0
set_defaults :Time?, :timestamp, :default => nil
```

Finally, the `timestamp` helper can be used to create the
`create_time` and `update_time` timestamps for you.

## Using the command

Using the command should be pretty straightforward.
Try `miguel -h` and follow the examples.
You can basically:

* `show` - show schema loaded from given `.rb` file or from given database.
* `dump` - dump migration which creates such schema.
* `down` - dump migration which reverses given schema entirely.
* `diff` - dump migration for migrating from one schema to another.
* `apply` - apply given schema to given database.
* `clear` - entirely wipe out schema of given database.

You don't have to worry about changing things accidentally,
the command will always ask for a confirmation before changing anything in the database
(unless you use the `--force` option).

Databases can be specified either by their Sequel URL like
`mysql2://user:password@localhost/main`,
or by the common database `.yml` config file:

``` yaml
adapter: mysql2
user: jim
password: sup3rsecr3t
host: localhost
database: main
encoding: utf8
```

Note that you can use the `--env` option to specify an environment other than `development`
if your `.yml` contains configs for multiple environments.

Use the `--migration <format>` option to choose how you want the migration displayed.
The `bare` format (the default) shows just the changes themselves,
the `change` format creates the one-way Sequel's change migration,
relying on Sequel's ability to reverse it,
while
the `full` format creates the two-way Sequel's up/down migration.

It's up to you if you will use `diff` each time to create the migration files for you,
amend them if needed,
and then let the `sequel` command use them normally,
or if you will just `apply` the schema directly
and rely on your VCS to keep its previous versions for you,
leaving dozens of piecewise migration files finally behind.

## Limitations

The type support is geared towards the MySQL, especially the timestamp types.
Generic types should work with any database, but your mileage may vary.

It is currently not possible to describe renaming of columns.
If you need that,
simply rename the columns directly in the database or by using standard Sequel migration,
and adjust the schema description accordingly.

## Credits

Copyright &copy; 2015 Patrik Rak

Miguel is released under the MIT license.
