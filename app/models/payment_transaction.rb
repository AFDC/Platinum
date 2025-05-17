class PaymentTransaction
  include Mongoid::Document
  include Mongoid::Timestamps
  field :transaction_id
  field :payment_method
  field :amount, type: BigDecimal
  field :service_fee, type: BigDecimal
  field :currency
  field :refunded_amount, type: BigDecimal

  belongs_to :user
  belongs_to :league
  belongs_to :registration
  belongs_to :pickup_registration
  has_one :donation
end