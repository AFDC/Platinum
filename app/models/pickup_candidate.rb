class PickupCandidate
    include Mongoid::Document
    include Mongoid::Timestamps
    include Rankable


    belongs_to :user
    belongs_to :league

    has_many :pickup_registrations

    field :notes, type: String

    def days_played
        pickup_registrations.accepted.count
    end

    def last_played
        pickup_registrations.accepted.order_by(assigned_date: 'desc').first&.assigned_date
    end
end
