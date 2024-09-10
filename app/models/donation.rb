class Donation
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :user
    belongs_to :registration

    belongs_to :payment_transaction

    field :amount, type: Float
    field :earmark, type: String

    validates :amount, :numericality => { integer_only: false, greater_than: 0 }
end