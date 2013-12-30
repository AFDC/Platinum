class League
  include Mongoid::Document
  field :name
  field :age_division
  field :season
  field :sport
  field :start_date, type: Date
  field :end_date, type: Date
  field :needs_standings_update, type: Boolean
  field :price, type: Integer
  field :registration_open, type: Date
  field :registration_close, type: Date

  has_many :teams, order: {'stats.rank' => :asc}
  has_and_belongs_to_many :commissioners, class_name: "User", foreign_key: :commissioner_ids, inverse_of: nil

  scope :past,    -> { where(:end_date.lt => Date.today).order_by(start_date: :desc) }
  scope :future,  -> { where(:registration_open.gt => Date.today).order_by(start_date: :desc) }
  scope :current, -> { where(:registration_open.lte => Date.today, :end_date.gte => Date.today).order_by(start_date: :desc) }
end