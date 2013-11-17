class FieldSite
	include Mongoid::Document
	field :name
	field :active, type: Boolean
	field :latitude, type: Float
	field :longitude, type: Float
	field :map_url
	field :directions

	has_many :games

    validates :name, presence: true
    validates :latitude, numericality: { integer_only: false, greater_than: -90, less_than: 90, allow_blank: true  }
    validates :longitude, numericality: { integer_only: false, greater_than: -180, less_than: 180, allow_blank: true  }

    def next_day_of_games
        return Date.today
    end
end
