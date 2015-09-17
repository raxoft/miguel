# Example schema for Miguel.
#
# Few words on indexes/indices, applying to Sequel migrations in general:
#
# Create explicit indexes even for foreign keys, to make them named the Sequel way.
# This also prevents MySQL from using combined index starting with that column for the foreign key.
# Such combined index couldn't be dropped later because of the foreign key constraint,
# at least until you would create an explicit one for that single column.
#
# Do not create overly complicated indexes before performance proves you really need them.
# Remember that every index increases insertion time considerably and takes space,
# so you should always start only with the basic indexes for the fields you need.

Miguel::Schema.define do

  set_standard_defaults

  # The user, the core of every web site.

  table :users do
    primary_key :id

    # The login id, usually user email address.
    String :login
    # The encrypted password.
    String :password

    # Random bytes associated with this user, used in hashing and encrypting user specific things.
    String :secret

    # First name(s).
    String :first_name
    # Last name(s).
    String :last_name

    # String describing which permissions and what access rights the user has, separated by comma.
    Text :permissions

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

  # Event log, for recording various things which happen on this web site.
  # Every event contains what kind of object it refers to, what action was taken,
  # what object was involved, if any, and arbitrary additional info stored as JSON.

  table :events do
    primary_key :id

    # The kind of the object affected (like user or email)
    String :kind
    # What action was taken (like create or update)
    String :action

    # Id of the user the event relates to, if any.
    foreign_key? :user_id, :users
    # Id of the user responsible for creating the event, if any.
    foreign_key? :author_id, :users
    # Id of the object involved, whatever it is, for easier database lookup.
    Unsigned? :subject_id

    # IP of the request, if any.
    String? :ip

    # Arbitrary JSON encoded info.
    Text :info

    timestamps

    index [ :kind, :action ]
    index :user_id
    index :author_id
    index :subject_id
    index :ip
    index :create_time
  end

  # User's followers.

  join_table :user_id, :user, :follower_id, :user, :user_followers

end

# EOF #
