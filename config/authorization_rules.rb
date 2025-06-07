	# Existing Roles
	# "user",
	# "steering-committee",
	# "league-manager",
	# "sc-emeritus",
	# "admin",
	# "comp-leagues"

authorization do
	role :guest do
		has_permission_on :dashboard, to: [:homepage]
		has_permission_on :help, to: [:login, :registration, :toc, :privacy]
		has_permission_on :schedules, to: [:index, :show]
		has_permission_on :leagues, to: [:index, :show, :cachekey]
		has_permission_on :users, to: [:new, :create]
		has_permission_on :teams, to: [:show, :index, :search]
		has_permission_on :fields, to: [:index, :show]
		has_permission_on :auth, to: [:index, :login, :logout, :forgot_password, :reset_password]
		has_permission_on :covid, to: [:index]
		has_permission_on :waivers, to: [:show, :sign_waiver]
		has_permission_on :waiver_signatures, to: [:show]
	end

	role :user do
		includes :guest

		# Things all users can do:
		has_permission_on :users, to: [:index, :search, :show]
		has_permission_on :teams, to: [:index, :search, :show, :view_roster]
		has_permission_on :registration_groups, to: [:index]
		has_permission_on :registrations, to: [:create]
		has_permission_on :payments, to: [:create, :pre_authorize]
		has_permission_on :leagues, to: [:register, :registrations, 
			:invite_pair, :leave_pair, :missing_spirit_reports, :team_list, :reg_list, 
			:volunteer_to_pickup, :pickup_registration, :pay_pickup]
		has_permission_on :profile, to: [:index, :edit_g_rank, :update_g_rank]
		has_permission_on :spirit_reports, to: [:index, :new, :create, :show, :edit, :update]
		has_permission_on :attendances, to: [:show, :create, :update] do
			if_attribute user_id: is { user._id }
		end

		has_permission_on :waivers, to: [:signatures] do
			if_attribute admin_ids: contains { user._id }
		end

		# Things a user can do IFF the record belongs to them:
		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar, :registrations, :edit, :update] do
			if_attribute :_id => is { user._id }
		end

		has_permission_on :registrations, to: [:checkout, :show, :pay, :donate, :waitlist_authorize, :edit, :update, :cancel] do
			if_attribute user_id: is { user._id }
		end

		has_permission_on :notification_methods, to: [:index, :new, :create, :edit, :update, :show, :enter_confirmation, :confirm, :destroy] do
			if_attribute user_id: is { user._id }
		end

		# User assignments (league commissioner, team captain, etc...)
		has_permission_on :teams, :to => [:edit, :update, :report_score, :modify_name, :report_spirit_score, :show_attendance] do
			if_attribute :captains => contains { user }
		end


		has_permission_on :teams, :to => [:report_score] do
			if_attribute :reporters => contains { user }
		end

		has_permission_on :leagues, :to => [:manage] do
			if_attribute commissioners: contains { user }
		end

		has_permission_on :leagues, :to => [
			:manage_roster, :finances, :players, :reg_list, :team_list, :cancel_registration, 
			:promote_waitlisted_registration, :add_player_to_team, :update_invites, :edit, :update, 
			:setup_schedule_import, :upload_schedule, :import_schedule, :remove_future_games, :rainout_games, :process_rainout, 
			:upload_roster, :setup_roster_import, :import_roster, :pickup_list, :invite_pickup] do

			if_permitted_to :manage
		end

		has_permission_on :games, :to => [:edit_score, :update_score] do
			if_attribute :teams => intersects_with { user.may_report_for }
		end

		# League Manager Permissions -- this applies to both universal league managers and also comissioners of individual leagues
		has_permission_on :teams, to: [:new, :create, :edit, :update, :modify_name, :modify_captains, :report_score, :show_attendance] do
			if_permitted_to :manage, :league
		end

		has_permission_on :leagues, to: [:show_attendance] do
			if_permitted_to :manage
		end

		has_permission_on :registration_groups, to: [:new, :create, :edit, :update, :add_to_team, :invite_players] do
			if_permitted_to :manage, :league
		end

		has_permission_on :registrations, to: [:edit, :update, :show, :cancel, :delete] do
			if_permitted_to :manage, :league
		end

		has_permission_on :games, to: [:edit_score, :update_score] do
			if_permitted_to :manage, :league
		end

	end

	role :'roster-manager' do
		has_permission_on :leagues, to: [:upload_roster, :setup_roster_import, :import_roster]
	end

	role :'league-manager' do
		has_permission_on :leagues, to: [:manage, :finances, :upload_roster, :setup_roster_import, :import_roster, :new, :create, :assign_comps, :pickup_list]

		has_permission_on :comp_groups, :to => [:index, :show, :new, :create, :edit, :update]
		has_permission_on :waivers, to: [:index, :new, :create, :edit, :update, :destroy, :signatures]
		has_permission_on :waiver_signatures, to: [:show]
		has_permission_on :teams, to: [:show_attendance]
		has_permission_on :leagues, to: [:show_attendance]
	end

	role :'spirit-manager' do 
		has_permission_on :leagues, to: [:manage_spirit]
	end

	role :'covid-admin' do
		has_permission_on :covid, to: [:confirm_vax_status]
	end

	role :admin do
		includes :'league-manager'
		includes :'spirit-manager'
		includes :'covid-admin'

		has_permission_on :teams, to: [:show_attendance]
		has_permission_on :leagues, to: [:show_attendance]
		has_permission_on :invitations, to: [:index]

		has_permission_on :invitations, to: [:show, :accept, :decline] do
			if_attribute recipient_id: is { user._id }
		end

		has_permission_on :invitations, to: [:show, :cancel] do
			if_attribute sender_id: is { user._id }
		end

		has_permission_on :global, :to => [:see_debug]

		has_permission_on :users, :to => [:edit_avatar, :update_avatar, :destroy_avatar, :login_as, :edit_permissions]

		has_permission_on :dashboard, to: [:audit_logs]

		has_permission_on :waivers, to: [:index, :new, :create, :edit, :update, :destroy, :signatures]
	end
end
