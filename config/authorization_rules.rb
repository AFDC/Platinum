authorization do
	role :guest do
		has_permission_on :users, to: [:new, :create]
	end
	role :user do
		includes :guest
		has_permission_on :users, to: [:index, :search, :read, :show]

		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar] do
      		if_attribute :_id => is { user._id }
    	end
	end 
end