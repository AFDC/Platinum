class AuditLog
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :acting_user, class_name: 'User'

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

    def self.log(action, target, details = {})
      log_entry = {action: action}

      log_entry[:acting_user] = details.delete(:acting_user)
      log_entry[:details]     = details

      if target
        log_entry[:target_class] = target.class.to_s
        log_entry[:target_id]    = target._id
      end

      create(log_entry)
    end
end
