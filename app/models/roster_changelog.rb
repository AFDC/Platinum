class RosterChangelog
    include Mongoid::Document
    include Mongoid::Timestamps 
    include ActiveModel::ForbiddenAttributesProtection
  
    belongs_to :player, class_name: "User"
    belongs_to :acting_user, class_name: "User"
    belongs_to :team
    belongs_to :league

    field :draft_id, type: Integer
    field :action, type: String
    field :notes, type: String

    validates :action, inclusion: { in: %w(add remove) }
    validates :player, presence: true
    validates :team, presence: true
    validates :league, presence: true

    def self.log_addition(player, acting_user, team)
        create!(
            player: player, 
            acting_user: acting_user, 
            team: team, 
            league: team.league, 
            action: 'add'
        )
    end

    def self.log_removal(player, acting_user, team)
        create!(
            player: player, 
            acting_user: acting_user, 
            team: team, 
            league: team.league, 
            action: 'remove'
        )
    end
end