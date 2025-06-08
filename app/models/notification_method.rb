class NotificationMethod
    include Mongoid::Document
    include ActiveModel::ForbiddenAttributesProtection

    before_validation :strip_phonenumber, :downcase_target
    before_create :initialize_confirmation

    field :method
    field :target
    field :confirmed
    field :confirmation_code
    field :enabled
    field :label

    belongs_to :user

    validates :method, inclusion: {in: %w(email text), message: "Must be email or text message."}
    validate :valid_target
    validates_uniqueness_of :target, scope: :user_id, message: "You already have a notification method for this."

    def status
        return :not_confirmed unless confirmed?
        return :disabled unless enabled?
        
        :enabled
    end

    def send_text(message)
        return if method != 'text'
        
        twilio_client = Twilio::REST::Client.new(ENV['twilio_sid'], ENV['twilio_token'])
        twilio_client.messages.create({ 
            from: ENV['twilio_number'], 
            to:   target,
            body: message
        })        
    end

    private

    def strip_phonenumber
        self.target = target.gsub(/\D/, '') if method == 'text'
    end

    def downcase_target
        self.target = target.downcase
    end

    def initialize_confirmation
        if target == user.email_address
            self.confirmed = true
            self.enabled   = true
            return
        end

        self.confirmed = false
        self.enabled   = false

        if method == 'text'
            self.confirmation_code = (SecureRandom.random_number(900000) + 100000).to_s
        else
            self.confirmation_code = SecureRandom.hex
        end
    end

    def valid_target
        if method == 'text'
            errors.add(:target, "That doesn't look like a phone number.") unless target.length == 10
        end

        if method == 'email'
            errors.add(:target, "That doesn't look like an email address.") unless target.include? '@'
        end
    end
end
