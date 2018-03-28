class AuditLog
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :acting_user, class_name: 'User'

    belongs_to :league
    belongs_to :registration
    belongs_to :user

    field :action, type: String

    field :target_class, type: String
    field :target_id, type: Moped::BSON::ObjectId

    field :details, type: Hash, default: {}

    validates :target_class, inclusion: { in: %w(User League Registration) }, allow_nil: true

    def target
      if target_class.nil? || target_id.nil?
        return nil
      end

      target_class.constantize.find(target_id)
    end
end
