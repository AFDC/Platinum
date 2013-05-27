class Team
  include Mongoid::Document
  has_and_belongs_to_many :players, class_name: "User", foreign_key: :players
  belongs_to :league
end