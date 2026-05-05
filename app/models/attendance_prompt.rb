class AttendancePrompt
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w(pending yes no partial).freeze
  RESPONSE_METHODS = %w(sms email web captain_override).freeze

  field :game_ids, type: Array, default: []
  field :game_day, type: Date
  field :status, type: String, default: 'pending'
  field :note, type: String
  field :response_method, type: String
  field :responded_at, type: DateTime
  field :actually_attended, type: Boolean
  field :web_token, type: String

  belongs_to :user
  belongs_to :team
  belongs_to :league
  belongs_to :responded_by, class_name: 'User', inverse_of: nil

  validates :status, inclusion: { in: STATUSES }
  validates :response_method, inclusion: { in: RESPONSE_METHODS, allow_nil: true }
  validates :user, :team, :league, :game_day, presence: true
  validates :game_day, uniqueness: { scope: [:user_id, :team_id] }

  before_validation :ensure_web_token

  scope :active_pending, -> { where(status: 'pending', :game_day.gte => Date.current) }
  scope :for_user,       ->(u) { where(user_id: u._id) }
  scope :for_team,       ->(t) { where(team_id: t._id) }
  scope :for_game_day,   ->(d) { where(game_day: d) }

  def record_response!(status:, responded_by:, response_method:, note: nil)
    raise ArgumentError, "invalid status #{status}" unless STATUSES.include?(status)
    raise ArgumentError, "invalid response_method #{response_method}" unless RESPONSE_METHODS.include?(response_method)

    self.status = status
    self.responded_by = responded_by
    self.response_method = response_method
    self.note = note if note
    self.responded_at = Time.now.in_time_zone(LOCAL_TIMEZONE)
    save!
  end

  private

  def ensure_web_token
    self.web_token ||= SecureRandom.hex(16)
  end
end
