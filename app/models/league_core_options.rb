class LeagueCoreOptions
  include Mongoid::Document
  include ActiveModel::ForbiddenAttributesProtection
  embedded_in :league

  field :type
  field :male_limit, type: Integer
  field :female_limit, type: Integer
  field :rank_limit, type: Float
  field :male_rank_coefficient, type: Float, default: 1.0
  field :male_rank_constant, type: Float, default: 0.0
  field :female_rank_coefficient, type: Float, default: 1.0
  field :female_rank_constant, type: Float, default: 0.0

  validates :type, :inclusion => { in: %w(pod core), allow_blank: true }
  validates :male_limit, :numericality => { integer_only: true, greater_than: 0, allow_blank: true }
  validates :female_limit, :numericality => { integer_only: true, greater_than: 0, allow_blank: true }
  validates :rank_limit, :numericality => { integer_only: false, greater_than: 0, allow_blank: true }
  validates :male_rank_coefficient, :numericality => { integer_only: false, allow_blank: false }
  validates :male_rank_constant, :numericality => { integer_only: false, allow_blank: false }
  validates :female_rank_coefficient, :numericality => { integer_only: false, allow_blank: false }
  validates :female_rank_constant, :numericality => { integer_only: false, allow_blank: false }
end
