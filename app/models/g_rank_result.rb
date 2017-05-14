class GRankResult
    include Mongoid::Document
    include ActiveModel::ForbiddenAttributesProtection

    field :answers, type: Hash, default: {}
    field :timestamp, type: Date, default: -> {Time.zone.current}
    field :score, type: Float

    belongs_to :user
    has_many :registrations

    validates :score, :numericality => { integer_only: false }
end