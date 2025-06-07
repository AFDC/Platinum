class Attendance
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::ForbiddenAttributesProtection

  field :game_date, type: Date
  field :attending, type: Boolean
  field :notes, type: String

  belongs_to :user
  belongs_to :team

  validates :game_date, presence: true
  validates :attending, inclusion: { in: [true, false] }
  validates :user, presence: true
  validates :team, presence: true
  validates :game_date, uniqueness: { scope: [:user_id, :team_id] }

  scope :for_date, ->(date) { where(game_date: date) }
  scope :attending, -> { where(attending: true) }
  scope :not_attending, -> { where(attending: false) }

  def status_display
    attending? ? 'Attending' : 'Not Attending'
  end
end