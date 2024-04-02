class League
  include Mongoid::Document
  include ActiveModel::ForbiddenAttributesProtection
  include Mongoid::Timestamps
  field :name
  field :age_division
  field :season
  field :sport
  field :start_date, type: Date, default: 5.weeks.from_now.to_date
  field :end_date, type: Date, default: 15.weeks.from_now.to_date
  field :needs_standings_update, type: Boolean
  field :female_limit, type: Integer
  field :male_limit, type: Integer
  field :price, type: Integer
  field :price_women, type: Integer
  field :registration_open, type: Date, default: 2.weeks.from_now.to_date
  field :registration_close, type: Date, default: 4.weeks.from_now.to_date

  field :male_registration_open, type: Date
  field :male_registration_close, type: Date
  field :female_registration_open, type: Date
  field :female_registration_close, type: Date

  field :description, type: String

  # Options
  field :max_grank_age, type: Integer, default: nil
  field :allow_self_rank, type: Boolean, default: true
  field :self_rank_type, type: String
  field :allow_pairs, type: Boolean, default: true
  field :eos_tourney, type: Boolean, default: true
  field :mst_tourney, type: Boolean, default: false
  field :track_spirit_scores, type: Boolean, default: false
  field :display_spirit_scores, type: Boolean, default: false
  field :invited_player_ids, type: Array, default: []
  field :covid_vax_required, type: Boolean, default: false
  embeds_one :core_options, class_name: 'LeagueCoreOptions'
  field :solicit_donations, type: Boolean, default: false

  field :donation_earmark, type: String, default: nil
  field :donation_pitch, type: String, default: nil

  after_initialize :build_options_if_nil
  after_find :migrate_self_rank_opts

  has_many :games
  has_many :teams, order: {league_rank: :asc}
  has_many :registrations
  has_many :registration_groups
  has_many :payment_transactions
  has_and_belongs_to_many :commissioners, class_name: "User", foreign_key: :commissioner_ids, inverse_of: nil
  has_and_belongs_to_many :comped_groups, class_name: "CompGroup", inverse_of: nil
  has_and_belongs_to_many :comped_players, class_name: "User", inverse_of: nil
  belongs_to :eos_champion, class_name: "Team", inverse_of: nil
  belongs_to :mst_champion, class_name: "Team", inverse_of: nil

  validates :name, :presence => true
  validates :price, :numericality => { integer_only: true, greater_than: 0, less_than: 250, allow_blank: false  }
  validates :price_women, :numericality => { integer_only: true, greater_than: 0, less_than: 250, allow_blank: true  }
  validates :self_rank_type, :inclusion => { in: %w(simple detailed none) }
  validates :age_division, :inclusion => { in: %w(adult juniors) }
  validates :season, :inclusion => { in: %w(fall winter spring summer saturday) }
  validates :sport, :inclusion => { in: %w(ultimate goaltimate) }
  validates :max_grank_age, :numericality => { integer_only: true, greater_than: 0, less_than: 24, allow_blank: true }
  validates :female_limit, :numericality => { integer_only: true, greater_than_or_equal_to: 0, allow_blank: true }
  validates :male_limit, :numericality => { integer_only: true, greater_than_or_equal_to: 0, allow_blank: true }

  scope :ended, -> { where(:end_date.lt => Time.current.to_date).order_by(start_date: :desc) }
  scope :not_ended, -> { where(:end_date.gte => Time.current.to_date).order_by(start_date: :desc) }
  scope :started, -> { where(:start_date.lte => Time.current.to_date, :end_date.gte => Time.current.to_date).order_by(start_date: :desc) }
  scope :not_started, -> { where(:start_date.gte => Time.current.to_date).order_by(start_date: :desc) }

  def get_price(gender = nil)
    if gender == "female" and price_women.present?
      return price_women
    end

    return price
  end

  def general_registration_open?
    return false if registration_open.nil? || registration_close.nil?

    open_time_on_date(registration_open).past? && close_time_on_date(registration_close).future?
  end

  def gender_permitted?(gender)
    limit = gender_limit(gender)
    return (limit.nil? == false && limit > 0)
  end

  def registration_open_for?(user)
    # Just return general open/closed status if no user is supplied
    return general_registration_open? if user.nil?

    # Bail out early if the gender is blocked
    return false unless gender_permitted?(user.gender)

    return (general_registration_open? || registration_open_for_gender?(user.gender) || is_invited?(user))
  end

  def registration_open_for_gender?(gender)
    return false unless gender == 'male' || gender == 'female'

    open_date  = self["#{gender}_registration_open"]
    close_date = self["#{gender}_registration_close"]

    return false if open_date.nil? || close_date.nil?

    open_time_on_date(open_date).past? && close_time_on_date(close_date).future?
  end

  def started?
    start_date.beginning_of_day < Time.now
  end

  def require_grank?
    max_grank_age.present?
  end

  def comped?(user)
    return true if comped_player_ids.include? user._id
    return true if comped_groups.collect(&:member_ids).flatten.include? user._id
    false
  end

  def gender_limit(gender)
    self["#{gender}_limit".to_sym]
  end

  def update_standings!
    # Update stats and sort the league
    team_cache = teams.to_a
    team_cache.each { |t| t.update_stats }.sort!.reverse!

    # Apply ranks, handle ties
    rank = 0
    team_cache.each_with_index do |this_team, order|
      unless (this_team <=> team_cache[order-1]) == 0
        rank += 1
      end

      this_team.league_rank = rank
      this_team.save
    end
  end

  def add_player_to_team(user,team,send_mail=true)
    raise ArgumentError.new "Must supply a user account to add" unless user.instance_of?(User)
    raise ArgumentError.new "Must supply a team to be added to" unless team.instance_of?(Team)
    raise ArgumentError.new "Team not a part of this league" unless team.league == self

    return true if self.team_for(user) == team

    # remove user from all teams in the league
    Team.collection.find(_id: {'$in' => self.team_ids}).update({"$pull" => {players: user._id}}, {multi: true})

    # remove all league teams from player
    User.collection.find(_id: user._id).update({"$pullAll" => {teams: self.team_ids}})

    # add player to team
    Team.collection.find({_id: team._id}).update({"$addToSet" => {players: user._id}}, {multi: false})

    # add team to player
    User.collection.find(_id: user._id).update({"$addToSet" => {teams: team._id}})

    if (send_mail)
      TeamMailer.delay.added_to_team(user._id.to_s, team._id.to_s)
    end
  end

  def handle_accepted_invite(invitation)
    if invitation.type == 'pair'
      sender_reg = registration_for(invitation.sender)
      recipient_reg = registration_for(invitation.recipient)

      unless sender_reg.present? && recipient_reg.present?
        raise "Registrations not found."
      end

      if sender_reg.linked? || recipient_reg.linked?
        return false
      end

      sender_reg.pair = invitation.recipient
      recipient_reg.pair = invitation.sender

      # We ignore validation errors because pairs can be confirmed before registation is complete which can lead to some odd errors
      sender_reg.save(validate: false)
      recipient_reg.save(validate: false)
    end
  end

  def registration_for(user)
    if user
      registrations.where({user_id: user._id}).first
    end
  end

  def team_for(user)
    if user
      teams.where({players: user}).first
    end
  end

  def current_expiration_time
    10.minutes.from_now
  end

  def current_expiration_times
    { male: current_expiration_time, female: current_expiration_time }
  end

  def invite!(player)
    return if is_invited?(player)

    self[:invited_player_ids] << player._id
    save!
    UserMailer.delay.league_invite(player._id.to_s, _id.to_s)
  end

  def is_invited?(player)
    invited_player_ids.include?(player._id)
  end

  def invited_players
    User.find(invited_player_ids)
  end

  def fill_slots_from_waitlist
    return if general_registration_open? == false
    slots_filled = 0

    genders = ["male", "female"]
    genders.each do |gender|
      next if registrations.waitlisted.where(gender: gender).count == 0

      gender_limit = gender_limit(gender)
      current_slots_filled = registrations.where(gender: gender, :status.in => ["active", "registering", "queued", "waitlisted_paying"])
      while registrations.where(gender: gender, :status.in => ["active", "registering", "queued", "waitlisted_paying"]).count < gender_limit
        break if registrations.where(gender: gender, status: "waitlisted", :waitlist_timestamp.exists => true).count == 0

        reg = registrations.where(gender: gender, status: "waitlisted", :waitlist_timestamp.exists => true).order_by([:waitlist_timestamp, :asc]).first
        reg.update_attributes(status: "waitlisted_paying")
        puts "Attempting to activate registration for #{reg.user.name}"

        if comped?(reg.user) == false
          if reg["pre_authorization"].nil? || reg["pre_authorization"]["stored_payment_token"].nil?
            puts "\tNo payment method token found for #{reg.user.name}"
            reg.update_attributes(status: "canceled")
            #TODO: Send error email
            next
          end

          price = reg.price

          # COPIED FROM league.rb
          result = Braintree::Transaction.sale(
            amount: price,
            payment_method_token: reg["pre_authorization"]["stored_payment_token"],
            channel: 'leagues.afdc.com',
            options: {
              submit_for_settlement: true
            },
            custom_fields: {
              registration_id: reg._id.to_s,
              league_id:       reg.league._id.to_s,
              user_id:         reg.user._id.to_s
            },
            order_id: "registration:#{reg._id.to_s}"
          )

          if result.success?
            PaymentTransaction.create({
              transaction_id: result.transaction.id,
              payment_method: result.transaction.payment_instrument_type,
              amount:         result.transaction.amount,
              currency:       result.transaction.currency_iso_code,
              registration:   reg,
              user:           reg.user,
              league:         reg.league
            })
            reg.paid = true
            #log_audit('Pay', league: reg.league, registration: reg)
          else
            puts "\tPayment method failed for #{reg.user.name} (#{result.message})"
            reg.update_attributes(status: "canceled")
            #TODO: Send Error Email
            next
          end
        end
        puts "\tActivated!"
        reg.activate!
        slots_filled += 1
      end
    end

    return slots_filled
  end

  def self.fill_open_slots
    open_leagues = League.not_started
    puts "Filling Open Slots worker performing job... (open leagues: #{open_leagues.count})"

    open_leagues.each do |league|
      puts ":: #{league.name}"
      slots_filled = league.fill_slots_from_waitlist
      puts ":: #{league.name}: #{slots_filled} filled"
    end

    return nil
  end

  def self.expire_stale_registrations
    open_leagues = League.not_ended
    puts "RegistrationCancellationWorker performing job... (open leagues: #{open_leagues.count})"

    open_leagues.each do |league|
      expired_regs = league.registrations.expired.where(:status.ne => "expired").to_a

      puts "Processing Cancellations for #{league.name} (count: #{expired_regs.count})"

      # Process expirations
      expired_regs.each do |reg|
        puts "Cancelling registration for #{reg.user_data['firstname']} #{reg.user_data['lastname']}"
        reg.process_expiration
      end
    end
  end

  def invitations
    Invitation.where(handler_class: "League", handler_id: _id)
  end

  private

  def build_options_if_nil
    build_core_options if core_options.nil?
  end

  def migrate_self_rank_opts
    return if self.attributes.count <= 30
    return unless self_rank_type.nil?
    self["self_rank_type"] = "simple" if allow_self_rank == true
    self["self_rank_type"] = "none" if allow_self_rank == false
  end

  def open_time_on_date(open_date)
    Time.zone.parse("#{open_date} 12pm")
  end

  def close_time_on_date(close_date)
    Time.zone.parse("#{close_date}").end_of_day
  end
end
