class Waiver
    include Mongoid::Document
    include Mongoid::Timestamps

    has_and_belongs_to_many :admins, class_name: "User", inverse_of: nil

    field :league_default, type: Boolean, default: false
    field :special_event, type: Boolean, default: false
    field :active, type: Boolean, default: true

    field :signature_valid_for, type: Integer # number of days after the signature is valid
    
    field :name, type: String
    field :description, type: String
    field :url, type: String
    field :slug, type: String

    validates :url, presence: true
    validates :slug, presence: false, uniqueness: true
    validates :slug, format: { with: /\A[a-z0-9\-_]+\z/ }, if: -> { slug.present? }
    def self.get_current
        Waiver.where(active: true, league_default: true).order_by(created_at: :desc).first
    end
end
