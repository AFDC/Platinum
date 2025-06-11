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

    def price
        league.pickup_price
    end

    def activate_and_notify
        self.status = "accepted"
        if !self.save!
            return false
        end

        PickupMailer.delay.confirm(self._id.to_s)
        return true
    end

    def refund!(amount = nil)
        return false unless status == 'accepted'
        return false if comped

        pt = payment_transactions.first
        return false unless pt

        refund_amount = amount || pt.amount
        
        if refund_amount > pt.amount
            raise "Attempted to refund $#{refund_amount} but pickup registration was only $#{pt.amount}"
        end

        result = Braintree::Transaction.refund(pt.transaction_id, amount: ("%.2f" % refund_amount))

        unless result.success?
            raise result.errors.first.message
        end

        pt.refunded_amount = refund_amount
        pt.save

        self.status = 'canceled'
        save!
    end

    def paid?
        payment_transactions.any?
    end

    private

    def ensure_price
        self.price = league.pickup_price
    end
end