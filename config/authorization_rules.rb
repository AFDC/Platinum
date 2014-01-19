	# Existing Roles
	# "user",
	# "steering-committee",
	# "league-manager",
	# "sc-emeritus",
	# "admin",
	# "comp-leagues"

authorization do
	role :guest do
		has_permission_on :schedules, to: [:index, :show]
		has_permission_on :leagues, to: [:index, :show]
		has_permission_on :users, to: [:new, :create]
		has_permission_on :teams, to: [:show, :index, :search]
		has_permission_on :fields, to: [:index, :show]
		has_permission_on :registrations, to: [:approved, :cancelled]
	end

	role :user do
		includes :guest

		# Things all users can do:
		has_permission_on :users, to: [:index, :search, :show]
		has_permission_on :teams, to: [:index, :search, :show, :view_roster]
		has_permission_on :registrations, to: [:create]
		has_permission_on :leagues, to: [:register, :registrations]

		# Things a user can do IFF the record belongs to them:
		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar, :registrations] do
			if_attribute :_id => is { user._id }
		end

		has_permission_on :registrations, to: [:checkout, :show, :edit, :update, :cancel] do
			if_attribute user_id: is { user._id }
		end

		# User assignments (league commissioner, team captain, etc...)
		has_permission_on :teams, :to => [:edit, :update, :report_score] do
			if_attribute :captains => contains { user }
		end

		has_permission_on :teams, :to => [:report_score] do
			if_attribute :reporters => contains { user }
		end

		has_permission_on :leagues, :to => [:manage] do
			if_attribute commissioners: contains { user }
		end

		has_permission_on :leagues, :to => [:manage_roster, :capture_payments, :edit, :update] do
			if_permitted_to :manage
		end

		has_permission_on :games, :to => [:edit_score, :update_score] do
			if_attribute :teams => intersects_with { user.may_report_for }
		end

		# League Manager Permissions -- this applies to both universal league managers and also comissioners of individual leagues
		has_permission_on :teams, to: [:new, :create, :edit, :update, :modify_name, :modify_captains, :report_score] do
			if_permitted_to :manage, :league
		end

		has_permission_on :registrations, to: [:edit, :update, :show, :cancel, :delete] do
			if_permitted_to :manage, :league
		end

		has_permission_on :games, to: [:edit_score, :update_score] do
			if_permitted_to :manage, :league
		end
	end

	role :'league-manager' do
		has_permission_on :leagues, to: [:manage, :upload_roster, :setup_roster_import, :import_roster, :new, :create, :assign_comps]
	end

	role :admin do
		includes :'league-manager'

		has_permission_on :global, :to => [:see_debug]

		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar]

		has_permission_on :comp_groups, :to => [:index, :show, :new, :create, :edit, :update]
	end
end