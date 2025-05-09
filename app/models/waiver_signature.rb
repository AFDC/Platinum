class WaiverSignature
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :waiver
    belongs_to :registration
    belongs_to :user

    # For non-user signatures
    field :email, type: String
    field :email_confirmation, type: String
    
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

        id_verification_time = Time.now
        if registration.waiver_acceptance_date
            id_verification_time = registration.waiver_acceptance_date
        end

        signature = WaiverSignature.new(
            waiver: waiver, 
            registration: registration,
            user: registration.user,

            name: registration.user.name,

            identity_verified: true,
            identity_verification_method: "logged_in_user",
            identity_verification_timestamp: id_verification_time,

            expires_at: waiver.signature_valid_for&.days&.from_now
        )
        if signature.save!
            return signature
        else
            return nil
        end
    end
end
