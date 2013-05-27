class Identity
  include Mongoid::Document
  belongs_to :user
end
