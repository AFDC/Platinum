class Pronoun
  include Mongoid::Document
  field :label, type: String
  field :display, type: String
  field :default, type: Boolean

  scope :defaults, where(default: true)
end
