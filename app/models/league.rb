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
  field :registration_open, type: Date, default: 2.weeks.from_now.to_date
  field :registration_close, type: Date, default: 4.weeks.from_now.to_date
  field :description, type: String

  # Options
  field :max_grank_age, type: Integer, default: nil
  field :allow_self_rank, type: Boolean, default: true
  field :allow_pairs, type: Boolean, default: true
  field :eos_tourney, type: Boolean, default: true
  field :mst_tourney, type: Boolean, default: false
  embeds_one :core_options, class_name: 'LeagueCoreOptions'

  after_initialize :build_options_if_nil

  has_many :teams, order: {league_rank: :asc}
  has_many :registrations
  has_many :registration_groups
  has_and_belongs_to_many :commissioners, class_name: "User", foreign_key: :commissioner_ids, inverse_of: nil
  has_and_belongs_to_many :comped_groups, class_name: "CompGroup", inverse_of: nil
  has_and_belongs_to_many :comped_players, class_name: "User", inverse_of: nil

  validates :name, :presence => true
  validates :price, :numericality => { integer_only: true, greater_than: 0, less_than: 250, allow_blank: false  }
  validates :age_division, :inclusion => { in: %w(adult juniors) }
  validates :season, :inclusion => { in: %w(fall winter spring summer saturday) }
  validates :sport, :inclusion => { in: %w(ultimate goaltimate) }
  validates :max_grank_age, :numericality => { integer_only: true, greater_than: 0, less_than: 24, allow_blank: true }
  validates :female_limit, :numericality => { integer_only: true, greater_than: 0, allow_blank: true }
  validates :male_limit, :numericality => { integer_only: true, greater_than: 0, allow_blank: true }

  scope :past,    -> { where(:end_date.lt => Date.today).order_by(start_date: :desc) }
  scope :future,  -> { where(:registration_open.gt => Date.today).order_by(start_date: :desc) }
  scope :current, -> { where(:registration_open.lte => Date.today, :end_date.gte => Date.today).order_by(start_date: :desc) }

  def registration_open?
    return false if registration_open.nil? || registration_close.nil?

    registration_open.to_time.in_time_zone.change(hour: 12).past? && registration_close.to_time.in_time_zone.end_of_day.future?
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
      sender_reg.save!
      recipient_reg.save!
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

  private

  def build_options_if_nil
    build_core_options if core_options.nil?
  end
end
