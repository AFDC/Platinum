class AttendancePromptDispatch
  include Mongoid::Document
  include Mongoid::Timestamps

  CHANNELS = %w(sms email).freeze
  KINDS    = %w(initial reminder).freeze

  field :channel, type: String
  field :sent_at, type: DateTime
  field :prompts, type: Array, default: []  # [{ 'prompt_id' => '...', 'prefix' => 1 }, ...]
  field :provider_message_id, type: String
  field :kind, type: String
  field :target, type: String  # phone or email actually used

  belongs_to :user

  validates :channel, inclusion: { in: CHANNELS }
  validates :kind,    inclusion: { in: KINDS }
  validates :user, :sent_at, presence: true

  def prompt_for_prefix(prefix)
    prefix = prefix.to_i
    entry = prompts.detect { |p| p['prefix'].to_i == prefix }
    return nil unless entry
    AttendancePrompt.where(_id: entry['prompt_id']).first
  end

  def active_pending_prompts
    ids = prompts.map { |p| p['prompt_id'] }
    return [] if ids.empty?
    AttendancePrompt.active_pending.where(:_id.in => ids).to_a
  end

  def self.latest_active_for_user(user, channel: 'sms')
    where(user_id: user._id, channel: channel).order_by(sent_at: :desc).each do |dispatch|
      return dispatch if dispatch.active_pending_prompts.any?
    end
    nil
  end
end
