	# Existing Roles
	# "user",
	# "steering-committee",
	# "league-manager",
	# "sc-emeritus",
	# "admin",
	# "comp-leagues"

authorization do
	role :guest do
		has_permission_on :users, to: [:new, :create]
		has_permission_on :teams, to: [:show, :index, :search]
	end

	role :user do
		includes :guest
		has_permission_on :users, to: [:index, :search, :show]
		has_permission_on :teams, to: [:index, :search, :show, :view_roster]

		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar] do
			if_attribute :_id => is { user._id }
		end

		has_permission_on :leagues, :to => [:manage] do
			if_attribute commissioners: contains { user }
		end

		has_permission_on :teams, :to => [:edit, :update, :report_score] do
			if_attribute :captains => contains { user }
		end

		has_permission_on :teams, :to => [:report_score] do
			if_attribute :reporters => contains { user }
		end

		has_permission_on :teams, to: [:new, :create, :edit, :update, :modify_name, :modify_captains, :report_score] do
			if_permitted_to :manage, :league
		end
	end

	role :'league-manager' do
		has_permission_on :league, to: [:manage]
	end

	role :admin do
		includes :'league-manager'

		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar]
	end
end