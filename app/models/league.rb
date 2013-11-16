class League
  include Mongoid::Document
  has_many :teams
  has_and_belongs_to_many :commissioners, class_name: "User", foreign_key: :commissioner_ids, inverse_of: nil
end