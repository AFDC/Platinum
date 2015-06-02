class User
  include Mongoid::Document
  include Mongoid::Paperclip
  include ActiveModel::ForbiddenAttributesProtection
  include ActiveModel::SecurePassword

  field :address
  field :birthdate
  field :city
  field :email_address
  field :firstname
  field :gender
  field :handedness
  field :height, type: Integer
  field :lastname
  field :middlename
  field :occupation
  field :phone
  field :postal_code
  field :privacy
  field :state
  field :weight, type: Integer
  field :permission_groups, type: Array, default: ['user']

  field :password_digest
  field :remember_me_cookie
  has_secure_password

  has_mongoid_attached_file :avatar,
    default_url: lambda {|attachment| "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(attachment.instance.email_address.downcase)}?s=330&d=mm&r=r"},
    styles: {profile: '330x330>', roster: '160x160#', thumbnail: '32x32#'}

  has_many :g_rank_results, order: :_id.desc
  has_many :registrations
  has_many :payment_transactions
  has_many :notification_methods
  has_and_belongs_to_many :teams, foreign_key: :teams

  validates :firstname, :presence => true
  validates :lastname, :presence => true
  validates :email_address, :presence => true, :uniqueness => { case_sensitive: false }
  validates :height, :numericality => { integer_only: true, greater_than: 30, less_than: 96, allow_blank: true  }
  validates :weight, :numericality => { integer_only: true, greater_than: 60, less_than: 400, allow_blank: true }
  validates :handedness, :inclusion => { in: %w(left right both), message: "%{value} is not a valid option", allow_blank: true }
  validates :gender, :presence => true, :inclusion => { in: %w(male female) }
  validates :birthdate, :date_string => true

  before_save :downcase_email
  after_create :create_initial_notification_method

  def may_report_for
    Team.where({ '$or' => [{'captains' => id}, {'reporters' => id}]})
  end

  def braintree_customer_id
    cid = id.to_s
    begin
      Braintree::Customer.find(cid)
      return cid
    rescue Braintree::NotFoundError
      result = Braintree::Customer.create(
        id:         cid,
        first_name: firstname,
        last_name:  lastname,
        email:      email_address
      )

      return id.to_s if result.success?
      return nil
    rescue
      return nil
    end
  end

  def braintree_token
    Braintree::ClientToken.generate(customer_id: braintree_customer_id)
  end

  def absorb(old_user)
    raise ArgumentError.new "Must supply a user account to be absorbed" unless old_user.instance_of?(User)
    raise ArgumentError.new "You cannot absorb a user into a new record, please save it first." if new_record?

    backup_user = User.collection.find(_id: old_user._id).first.to_hash

    # Swap old_user off of teams, place new_user on teams
    team_ids = []
    old_user.teams.each do |t|
      team_ids << t._id
    end
    Team.collection.find(_id: {'$in' => team_ids}).update({"$pull" => {players: old_user._id}}, {multi: true})
    Team.collection.find(_id: {'$in' => team_ids}).update({"$addToSet" => {players: id}}, {multi: true})
    User.collection.find(_id: id).update({"$addToSet" => {teams: {"$each" => team_ids}}})

    # Handle Reporters and Captains
    reporter_for = Team.collection.find(reporters: old_user._id).map{|t| t["_id"]}
    Team.collection.find(_id: {'$in' => reporter_for}).update({"$pull" => {reporters: old_user._id}}, {multi: true})
    Team.collection.find(_id: {'$in' => reporter_for}).update({"$addToSet" => {reporters: id}}, {multi: true})

    captain_for = Team.collection.find(captains: old_user._id).map{|t| t["_id"]}
    Team.collection.find(_id: {'$in' => captain_for}).update({"$pull" => {captains: old_user._id}}, {multi: true})
    Team.collection.find(_id: {'$in' => captain_for}).update({"$addToSet" => {captains: id}}, {multi: true})

    # Assign old_user's registrations to new_user
    registrations = Registration.collection.find(user_id: old_user._id).map{|r| r["_id"]}
    Registration.collection.find(_id: {'$in' => registrations}).update({"$set" => {user_id: id}}, {multi: true})

    # Assign old_user's gRanks to new_user
    grr = GRankResult.collection.find(user_id: old_user._id).map{|r| r["_id"]}
    GRankResult.collection.find(_id: {'$in' => grr}).update({"$set" => {user_id: id}}, {multi: true})

    # Backup old_user object
    absorb_data = {
      teams_found: team_ids.map{|id| id.to_s},
      reporter_for: reporter_for.map{|id| id.to_s},
      captain_for: captain_for.map{|id| id.to_s},
      registrations: registrations.map{|id| id.to_s},
      grank_results: grr.map{|id| id.to_s}
    }

    backup_user[:absorb_data] = absorb_data

    File.open("log/user_absorption.log", "a+") do |f|
      f << "#{backup_user.to_json}\n"
    end

    User.collection.find(_id: old_user._id).remove
  end

  def downcase_email
  	self.email_address = self.email_address.downcase
  end

  def height_in_feet_and_inches
    height ? "#{height/12}\'#{height%12}\"" : 'n/a'
  end

  def name
    "#{firstname} #{lastname}"
  end

  def remember_me
    unless remember_me_cookie
      self.remember_me_cookie = SecureRandom.hex(32)
      save(validate: false)
    end

    remember_me_cookie
  end

  def forget_me
    self.remember_me_cookie = nil
    save(validate: false)
  end

  def age
    begin
      dob = Date.parse(birthdate)
      today = Date.today
      d = Date.new(today.year, dob.month, dob.day)
      d.year - dob.year - (d > today ? 1 : 0)
    rescue
      nil
    end
  end

  def role_symbols
    permission_groups.map(&:to_sym)
  end

  def reset_password
    self.password = SecureRandom.hex(10)
  end

  def self.find_by_email_address(email_address)
    User.where({email_address: /^#{Regexp.escape(email_address)}$/i}).first
  end

  def create_initial_notification_method
    notification_methods.create(label: "Account email notifier", method: "email", target: email_address)
  end
end
