authorization do
	role :guest do
		has_permission_on :users, to: [:new, :create]
	end
	role :user do
		includes :guest
		has_permission_on :users, to: [:index, :search, :read, :show]
	end 
end