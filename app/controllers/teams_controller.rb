class TeamsController < ApplicationController
	before_filter :load_team_from_params, only: [:show, :edit, :update]
	before_filter :load_league_from_params, only: [:new, :create]
	filter_access_to [:edit_avatar, :update_avatar, :destroy_avatar], :attribute_check => true

	def index
		@team_list = []
		if (params[:query])
			@team_list = Team.where({name: /#{params[:query]}/i})
		end
	end

	def new
		@team = Team.new
		@team.league = @league
	end

	def create
		@team = Team.new(team_params)
		@team.league = @league

		if @team.save
			redirect_to league_path(@league), notice: "Team Created Successfully"
		else
			render :new
		end
	end

	def update
		@team.update_attributes(team_params)
		redirect_to team_path(@team), notice: 'Team Updated!'
	end

	def attendance
		@team   = Team.find(params[:id])
		@league = @team.league
		@upcoming_days  = upcoming_game_days(@team)
		@prompts_by_day = {}
		@pickups_by_day = {}
		@counts_by_day  = {}
		@upcoming_days.each do |day|
			prompts = AttendancePrompt.where(team_id: @team._id, game_day: day).to_a
			pickups = PickupRegistration.where(team: @team, assigned_date: day, status: 'accepted').to_a
			@prompts_by_day[day] = prompts
			@pickups_by_day[day] = pickups
			@counts_by_day[day]  = build_attendance_counts(@team, prompts, pickups)
		end
	end

	def attendance_override
		@team  = Team.find(params[:id])
		prompt = AttendancePrompt.where(team_id: @team._id, _id: params[:prompt_id]).first
		head 404 and return unless prompt
		prompt.record_response!(
			status: params[:status],
			responded_by: current_user,
			response_method: 'captain_override',
			note: params[:note]
		)
		redirect_to attendance_team_path(@team), notice: "Updated #{prompt.user.firstname}'s response."
	end

	def bulk_attendance
		@team     = Team.find(params[:id])
		@game_day = Date.parse(params[:game_date])
		@players  = @team.players.to_a
		@games    = Game.where(:teams => @team._id,
								:game_time.gte => @game_day.beginning_of_day,
								:game_time.lte => @game_day.end_of_day).to_a
		@existing = AttendancePrompt.where(team_id: @team._id, game_day: @game_day).to_a.index_by(&:user_id)
	end

	def apply_bulk_attendance
		@team     = Team.find(params[:id])
		@game_day = Date.parse(params[:game_date])
		game_ids  = Game.where(:teams => @team._id,
								:game_time.gte => @game_day.beginning_of_day,
								:game_time.lte => @game_day.end_of_day).map(&:_id)

		(params[:attendance] || {}).each do |user_id, fields|
			status = fields['status']
			next if status.blank? || status == 'no_change'
			player = User.find(user_id)
			prompt = AttendancePrompt.where(team_id: @team._id, user_id: player._id, game_day: @game_day).first
			prompt ||= AttendancePrompt.new(team: @team, user: player, league: @team.league, game_day: @game_day)
			prompt.game_ids = game_ids
			prompt.save!
			prompt.record_response!(
				status: status,
				responded_by: current_user,
				response_method: 'captain_override',
				note: fields['note'].presence
			)
		end

		redirect_to attendance_team_path(@team), notice: "Bulk attendance updated for #{@game_day.strftime('%A %-m/%-d')}."
	end

	private

	def upcoming_game_days(team)
		end_of_week = Date.current.end_of_week + 1
		Game.where(:teams => team._id, :game_time.gte => Date.current.beginning_of_day, :game_time.lte => end_of_week.end_of_day)
				.map { |g| g.game_time.in_time_zone(LOCAL_TIMEZONE).to_date }
				.uniq
				.sort
	end

	def build_attendance_counts(team, prompts, pickups)
		by_gender = { 'male' => team.players.select { |p| p.gender == 'male' },
									'female' => team.players.select { |p| p.gender == 'female' } }
		pickup_by_gender = pickups.group_by { |pr| pr.user.gender }
		result = { total: bucket_zero, male: bucket_zero, female: bucket_zero }
		%w(male female).each do |gender|
			players = by_gender[gender]
			gender_prompts = prompts.select { |p| p.user && p.user.gender == gender }
			yes_count          = gender_prompts.count { |p| p.status == 'yes' || p.status == 'partial' }
			no_count           = gender_prompts.count { |p| p.status == 'no' }
			not_answered_count = gender_prompts.count { |p| p.status == 'pending' } + (players.count - gender_prompts.size)
			pickup_count       = (pickup_by_gender[gender] || []).size
			result[gender.to_sym] = { yes: yes_count + pickup_count, no: no_count, not_answered: not_answered_count, pickups: pickup_count }
		end
		result[:total] = {
			yes:          result[:male][:yes] + result[:female][:yes],
			no:           result[:male][:no] + result[:female][:no],
			not_answered: result[:male][:not_answered] + result[:female][:not_answered],
			pickups:      result[:male][:pickups] + result[:female][:pickups],
		}
		result
	end

	def bucket_zero
		{ yes: 0, no: 0, not_answered: 0, pickups: 0 }
	end

	def load_team_from_params
		@team = Team.find(params[:id])
		redirect_to teams_path, flash: {error: "Could not load team for ID '#{params[:id]}', please try a different team."} unless @team
	end

	def load_league_from_params	
		@league = League.find(params[:league_id])
	end

	def team_params
		permitted_params = [:avatar, {reporters: []}]

		if permitted_to? :modify_name
			permitted_params << :name
		end

		if permitted_to? :modify_captains
			permitted_params << {captains: []}
		end

		params.require(:team).permit(*permitted_params)
	end
end