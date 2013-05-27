class League
  include Mongoid::Document
  has_many :teams
end