class TeamsController < ApplicationController
	before_filter :load_team_from_params, only: [:show, :edit, :update, :show_attendance, :manage_attendance, :update_attendance]
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

	def show_attendance
		@attendances = Attendance.where(team: @team).desc(:game_date)
		@attendance_by_date = @attendances.group_by(&:game_date)
	end

	def manage_attendance
		@game_date = Date.parse(params[:game_date]) if params[:game_date]
		redirect_to team_path(@team), alert: "Game date is required." unless @game_date
		
		@attendances = Attendance.where(team: @team, game_date: @game_date)
		@attendance_by_user = {}
		@attendances.each { |att| @attendance_by_user[att.user_id] = att }
		
		@players = @team.players.sort_by { |p| [p.gender, p.name] }
	end

	def update_attendance
		@game_date = Date.parse(params[:game_date]) if params[:game_date]
		redirect_to team_path(@team), alert: "Game date is required." unless @game_date
		
		if params[:attendance]
			params[:attendance].each do |user_id, attendance_data|
				next if attendance_data[:attending].blank?
				
				user = User.find(user_id)
				attendance = Attendance.find_or_initialize_by(
					team: @team,
					user: user,
					game_date: @game_date
				)
				
				attendance.attending = attendance_data[:attending] == 'true'
				attendance.notes = attendance_data[:notes]
				attendance.updated_by = current_user
				attendance.save
			end
		end
		
		redirect_to show_attendance_team_path(@team, anchor: "date-#{@game_date.strftime('%Y-%m-%d')}"), 
					notice: "Attendance updated successfully."
	end

	private

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