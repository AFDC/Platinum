class Invitation
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::ForbiddenAttributesProtection

  field :type
  field :handler_class
  field :handler_id, type: Moped::BSON::ObjectId
  field :data, type: Hash, default: {}
  field :accept_key, default: ->{SecureRandom.hex(10)}
  field :status, default: 'new'

  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"

  after_create :send_invite

  scope :outstanding, where(:status.nin => %w(accepted declined canceled))

  validates :type, :inclusion => { in: %w(pair), message: "Unknown invitation type: %{value}", allow_blank: false }
  validates :status, :inclusion => { in: %w(new sent accepted declined canceled), message: "Unknown invitation status: %{value}", allow_blank: false }
  validates :sender, presence: true
  validates :recipient, presence: true

  def handler
    if self[:handler_id]
      return self[:handler_class].constantize.find(self[:handler_id])
    else
      return self[:handler_class].constantize
    end
  end

  def handler=(handler)
    if handler.is_a?(Class)
      self[:handler_class] = handler.to_s
      self[:handler_id] = nilr
    else
      self[:handler_class] = handler.class.to_s
      self[:handler_id] = handler._id
    end
  end


  def accept
    self[:status] = 'accepted'
    save!

    handler.handle_accepted_invite(self)

    InvitationMailer.delay.pair_request_result(self._id.to_s)
  end

  def decline
    self[:status] = 'declined'
    save!

    InvitationMailer.delay.pair_request_result(self._id.to_s)
  end

  def cancel
    self[:status] = 'canceled'
    save!
  end

  private

  def send_invite
    InvitationMailer.delay.pair_request(self._id.to_s)
  end
end
