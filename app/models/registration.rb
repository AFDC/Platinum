class Registration
    include Mongoid::Document
    field :paid, type: Boolean
    field :status
    field :player_strength
    field :signup_timestamp, type: DateTime
    field :payment_timestamps, type: Array
    field :pair, type: Hash
    field :gender
    field :availability, type: Hash
    field :team_style_pref, type: Hash
    field :secondary_rank_data, type: Hash
    field :waiver_acceptance_date, type: DateTime
    field :user_data, type: Hash
    field :notes

    belongs_to :user
    belongs_to :league

    def self_rank
        if secondary_rank_data.nil?
            nil
        else
            secondary_rank_data['self_rank']
        end
    end

    def waiver_accepted
        !waiver_acceptance_date.nil?
    end
end
