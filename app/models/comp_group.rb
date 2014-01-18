class CompGroup
    include Mongoid::Document
    include ActiveModel::ForbiddenAttributesProtection

    field :name
    field :description

    has_and_belongs_to_many :members, class_name: "User", inverse_of: nil
end

