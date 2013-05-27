class Team
  include Mongoid::Document
  field :name
  field :stats, type: Hash
  has_and_belongs_to_many :reporters, class_name: "User", foreign_key: :reporters, inverse_of: nil
  has_and_belongs_to_many :captains, class_name: "User", foreign_key: :captains, inverse_of: nil
  has_and_belongs_to_many :players, class_name: "User", foreign_key: :players
  belongs_to :league
end