class Registration
    include Mongoid::Document
    include Mongoid::Timestamps
    include Rankable

    field :paid, type: Boolean
    field :status
    field :pre_authorization
    field :waitlist_timestamp, type: DateTime
    field :signup_timestamp, type: DateTime
    field :payment_timestamps, type: Hash, default: {}
    field :pair, type: Hash
    field :gender
    field :availability, type: Hash
    field :team_style_pref, type: Hash
    field :shirt_size
    
    field :acceptance_expires_at, type: DateTime # DEPRECATED
    field :expires_at, type: DateTime
    field :queued_at, type: DateTime
    field :warning_email_sent_at, type: DateTime  

    field :waiver_acceptance_date, type: DateTime
    field :user_data, type: Hash
    field :notes
    field :comped, type: Boolean
    field :price, type: Float

    field :payment_id

    field :pair_id, type: BSON::ObjectId

    validate :has_valid_attendance_value, :has_signed_waiver

    belongs_to :user
    belongs_to :league
    belongs_to :pair, class_name: "User"
    has_many :payment_transactions
    has_one :donation
    has_one :waiver_signature

    before_save :ensure_price
    after_save  :bust_league_cache
    after_initialize :load_user_info, if: :new_record?

    scope :active, -> { where(status: 'active') }
    scope :registering, -> { where(status: 'registering', :expires_at.gt => Time.now) }
    scope :pending, -> { where(status: 'pending') }
    scope :canceled, -> { where(status: 'canceled') }
    scope :waitlisted, -> { where(status: 'waitlisted') }
    scope :registering_waitlisted, -> { where(status: 'registering_waitlisted') }
    scope :queued, -> { where(status: 'queued', :expires_at.gt => Time.now) }
    scope :expired, -> { any_of( {status: 'expired'}, {:status.in => ['registering','registering_waitlisted'], :expires_at.lte => Time.now} ) } 

    scope :male, -> { where(gender: 'male') }
    scope :female, -> { where(gender: 'female') }

    def gen_availability
        availability['general'] if availability
    end

    def eos_availability
        availability['attend_tourney_eos'] if availability
    end

    def ensure_price
        self.price = league.get_price(gender) unless self.price.present?
    end

    def formatted_signup_timestamp(format = :long)
        return "None" if signup_timestamp.nil?
        
        signup_timestamp.to_formatted_s(format)
    end

    def gender_noun
        User::gender_noun(gender)
    end

    # Pairing Stuff:

    def old_pair
        if self[:pair]
            self[:pair]['text']
        end
    end

    def linked?
        self.pair_id.present? || cored?
    end

    def cored?
        RegistrationGroup.where(league: self.league, member_ids: self[:user_id]).first.present?
    end

    def accept(expires_at = nil)
        self.status                = 'registering'
        self.warning_email_sent_at = nil
        self.expires_at = expires_at

        if self.save
            RegistrationMailer.delay.registration_accepted(self._id.to_s)
        end
    end

    def activate!
        self.status = 'active'
        save!
        RegistrationMailer.delay.registration_active(self._id.to_s)
    end

    def waitlist(pre_auth = nil)
        update_attributes(
            pre_authorization: pre_auth,
            waitlist_timestamp: Time.now,
            status: "waitlisted"
        )
        RegistrationMailer.delay.registration_waitlisted(self._id.to_s)
    end

    def can_cancel?
        return false if ['active', 'canceled'].include?(status)
        return false if new_record?
        true
    end

    def cancel
        return false if self.status == 'active'

        self.status = 'canceled'
        self.save
    end

    def refund!(amount = nil)
        return false unless status == 'active'
        return false if comped

        pt = payment_transactions.first

        refund_amount = amount || pt.amount
        if refund_amount > pt.amount
            raise "Attempted to refund $#{refund_amount} but registration was only $#{pt.amount}"
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

    def is_expired?
        return true  if status     == "expired"
        return false if status     == "active"
        return false if status     == "waitlisted"
        return false if expires_at == nil
        
        return (expires_at <= Time.now)
    end

    def process_expiration
        self.status                = 'expired'
        self.expires_at            = nil
        self.warning_email_sent_at = nil
        save!(validate: false) # registrations that haven't been filled out yet won't be valid
    
        AuditLog.create(
          action: 'Expire',
          league: league,
          registration: self
        )
    
        RegistrationMailer.unpaid_registration_cancelled(id.to_s).deliver        
    end

    def is_registering?
        return (status == 'registering') && (is_expired? == false)
    end

    def waiver_accepted
        !waiver_acceptance_date.nil?
    end

    def memoize_user_info(new_user = nil)
        self.user = new_user unless new_user.nil?

        if user.nil?
            raise "User not set"
        end

        self.gender = user.gender

        self.user_data = {
            birthdate: user.birthdate,
            firstname: user.firstname,
            middlename: user.middlename,
            lastname: user.lastname,
            gender: user.gender,
            height: user.height,
            weight: user.weight
        }
    end

    def count_earlier_queued_registrations
        return 0 unless status == 'queued'
        count = 0

        league.registrations.queued.where(gender: gender).each do |reg|
            next  if reg._id == self._id
            count += 1 if reg.queued_at < self.queued_at
        end

        count
    end

    # Validators
    def has_valid_attendance_value
        unless ['25%', '50%', '75%', '100%'].include?(gen_availability)
            errors.add(:gen_availability, "Please select an attendance percentage.")
        end
    end

    def has_signed_waiver
        if waiver_acceptance_date.nil?
            errors.add(:waiver_accepted, "You must accept the liability waiver and refund policy to register.")
        end
    end

    def sent_invitations
        league.invitations.where(sender: user)
    end

    def received_invitations
        league.invitations.where(recipient: user)
    end

    private

    def load_user_info
        memoize_user_info if user
    end

    def bust_league_cache
        self.league.touch
    end
end
