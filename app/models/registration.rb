class Registration
    include Mongoid::Document
    field :paid, type: Boolean
    field :status
    field :player_strength
    field :signup_timestamp, type: DateTime
    field :payment_timestamps, type: Hash, default: {}
    field :pair, type: Hash
    field :gender
    field :availability, type: Hash
    field :team_style_pref, type: Hash
    field :self_rank, type: Float
    field :commish_rank, type: Float
    field :g_rank, type: Float

    field :waiver_acceptance_date, type: DateTime
    field :user_data, type: Hash
    field :notes
    field :comped, type: Boolean

    field :paypal_responses, type: Array, default: []
    field :payment_id

    field :pair_id, type: Moped::BSON::ObjectId

    validates :commish_rank, :numericality => { integer_only: false, greater_than: 0, less_than: 10, allow_blank: true }

    belongs_to :user
    belongs_to :league
    belongs_to :g_rank_result
    belongs_to :pair, class_name: "User"

    after_save :bust_league_cache

    def gen_availability
        availability['general'] if availability
    end

    def eos_availability
        availability['attend_tourney_eos'] if availability
    end

    # Pairing Stuff:

    def old_pair
        if self[:pair]
            self[:pair]['text']
        end
    end

    def linked?
        self.pair_id.present? || RegistrationGroup.where(league: self.league, member_ids: self[:user_id]).first.present?
    end

    def rank
        self.commish_rank || self.g_rank || self.self_rank
    end

    def core_rank
        return nil unless self.rank
        return nil unless self.league.core_options.type

        constant = self.league.core_options["#{self.gender}_rank_constant"] || 0.0
        coefficient = self.league.core_options["#{self.gender}_rank_coefficient"] || 1.0

        (coefficient*self.rank)+constant
    end

    def waiver_accepted
        !waiver_acceptance_date.nil?
    end

    def capture_payment
        raise PaymentNotAuthorized if status != 'authorized'
        raise PaymentInfoMissing unless payment_id

        payment = PayPal::SDK::REST::Payment.find(payment_id)
        transaction = payment.transactions.first
        authorization = transaction.related_resources.first.authorization

        capture = authorization.capture({
            :amount => {
                :currency => "USD",
                :total => authorization.amount.total
            },
            :is_final_capture => true
        })

        self.paypal_responses << capture.to_json
        unless capture.success?
            save
            raise PaymentNotCaptured unless capture.success?
        end

        self.payment_timestamps[:captured] = Time.now
        self.paid = true
        self.status = 'active'
        save
    end

    def void_authorization
        raise PaymentNotAuthorized if status != 'authorized'
        raise PaymentInfoMissing unless payment_id

        payment = PayPal::SDK::REST::Payment.find(payment_id)
        transaction = payment.transactions.first
        authorization = transaction.related_resources.first.authorization

        voided = authorization.void

        if voided
            self.status = 'cancelled'
            self.payment_timestamps[:voided] = Time.now
            self.save
            true
        end

        voided
    end

    ## Exceptions
    class PaymentNotAuthorized < StandardError
    end

    class PaymentInfoMissing < StandardError
    end

    class PaymentNotCaptured < StandardError
    end

    private

    def bust_league_cache
        self.league.touch
    end
end
