class PickupRegistration
    include Mongoid::Document
    include Mongoid::Timestamps

    field :status, type: String, default: "invited"
    field :assigned_date, type: Date
    field :comped, type: Boolean, default: false
    field :price, type: Float

    belongs_to :user
    belongs_to :pickup_candidate
    belongs_to :league
    belongs_to :team

    has_many :payment_transactions
    has_one :waiver_signature

    validates :user, :pickup_candidate, :league, :team, :assigned_date, presence: true
    validates :status, inclusion: { in: ["invited", "accepted", "canceled", "declined"] }
    validates :assigned_date, :inclusion => { :in => Date.today..Date.today + 6.months }, on: :create

    scope :accepted, -> { where(status: "accepted") }
    scope :invited, -> { where(status: "invited") }

    def is_comped?
        comped || league.comped?(user)
    end

    def games
        league.games.where(date: self.assigned_date).order(start_time: 'asc')
    end

    private

    def ensure_price
        self.price = league.pickup_price
    end
end