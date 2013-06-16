class FieldSite
	include Mongoid::Document
	field :name
	field :active, type: Boolean
	field :latitude, type: Float
	field :longitude, type: Float
	field :map_url
	field :directions

	has_many :games
end