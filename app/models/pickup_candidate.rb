class PickupCandidate
    include Mongoid::Document
    include Mongoid::Timestamps
    include Rankable


    belongs_to :user
    belongs_to :league

    field :notes, type: String

    def days_played
        0
    end

    def last_played
        nil
    end
end
