class RegistrationGroup
  include Mongoid::Document
  include ActiveModel::ForbiddenAttributesProtection
  include Mongoid::Timestamps

  field :notes

  belongs_to :league
  has_and_belongs_to_many :members, class_name: "User", inverse_of: nil
  has_and_belongs_to_many :admins, class_name: "User", inverse_of: nil

  after_save :bust_league_cache

  private

  def bust_league_cache
      self.league.touch
  end
end
