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
  field :confirmed_covid_vax, type: Boolean, default: false
  field :confirmed_covid_booster, type: Boolean, default: false
  field :permission_groups, type: Array, default: ['user']
  field :minimum_rank, type: Integer

  field :password_digest
  field :remember_me_cookie

  has_secure_password

  has_mongoid_attached_file :avatar,
    default_url: lambda {|attachment| "http://www.gravatar.com/avatar/#{attachment.instance.email_md5}?s=330&d=mm&r=r"},
    styles: {profile: '330x330>', roster: '160x160#', thumbnail: '32x32#'},
    escape_url: false

  belongs_to :pronouns

  has_many :g_rank_results, order: :_id.desc
  has_many :registrations
  has_many :donations
  has_many :payment_transactions
  has_many :notification_methods
  has_many :pickup_leagues, class_name: "PickupCandidate"
  has_many :waiver_signatures
  has_and_belongs_to_many :teams, foreign_key: :teams

  validates :firstname, :presence => true
  validates :lastname, :presence => true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: { with: /.+@.+\.{1}.{2,}/ }
  validates :height, :numericality => { integer_only: true, greater_than: 30, less_than: 96, allow_blank: true  }
  validates :weight, :numericality => { integer_only: true, greater_than: 60, less_than: 400, allow_blank: true }
  validates :handedness, :inclusion => { in: %w(left right both), message: "%{value} is not a valid option", allow_blank: true }
  validates :gender, :presence => true, :inclusion => { in: %w(male female) }
  validates :birthdate, :required_age => 6, :date_string => true

  validates_attachment :avatar, content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

  before_save :downcase_email
  after_create :create_initial_notification_method

  def may_report_for
    Team.where({ '$or' => [{'captains' => id}, {'reporters' => id}]})
  end

  def gender_noun
    User::gender_noun(gender)
  end

  def self.gender_noun(gender)
    {"male" => "man-matching", "female" => "woman-matching"}[gender.to_s]
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
    self.email_address = email_address.try(:downcase)
  end

  def height_in_feet_and_inches
    height ? "#{height/12}\'#{height%12}\"" : 'n/a'
  end

  def name
    "#{firstname} #{lastname}"
  end

  def name_with_pronouns
    pronoun_text = ""
    if pronouns.present?
        pronoun_text = " (#{pronouns.display})"
    end
    return "#{name}#{pronoun_text}"
  end

  def needs_grank_update_for_league?(league)
    return false if league.require_grank? == false
    
    g_rank_results.first.nil? || (g_rank_results.first.timestamp.end_of_day < league.max_grank_age.months.ago)
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
    NotificationMethod.create(user: self, method: "email", target: email_address, label: "Account email notifier")
  end

  def email_md5
    Digest::MD5.hexdigest(downcase_email)
  end

  def registrations_with_payment_due
    registrations.registering.select {|reg| reg.league.started? == false}
  end
end
