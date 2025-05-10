class WaiverSignature
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :waiver
    belongs_to :registration
    belongs_to :user

    # For non-user signatures
    field :email, type: String
    field :confirmation_code, type: String
    
    field :name, type: String

    field :identity_verified, type: Boolean, default: false
    field :identity_verification_method, type: String
    field :identity_verification_timestamp, type: DateTime

    field :expires_at, type: DateTime

    validates :waiver, presence: true
    validates :email, presence: true, if: -> { user.blank? }

    def self.create_from_registration!(registration)
        waiver = Waiver.get_current
        return if waiver.blank?

        signature = WaiverSignature.new_from_user(registration.user, waiver)

        if registration.waiver_acceptance_date
            signature.identity_verification_timestamp = registration.waiver_acceptance_date
        end

        signature.registration = registration

        if signature.save!
            return signature
        else
            return nil
        end
    end

    def self.new_from_user(user, waiver)
        return WaiverSignature.new(
            waiver: waiver, 
            user: user,

            name: user.name,

            identity_verified: true,
            identity_verification_method: "logged_in_user",
            identity_verification_timestamp: Time.now,

            expires_at: waiver.signature_valid_for&.days&.from_now
        )
    end        
end
