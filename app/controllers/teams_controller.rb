class TeamsController < ApplicationController
	filter_access_to [:edit_avatar, :update_avatar, :destroy_avatar], :attribute_check => true
	before_filter :load_team_from_params, only: [:show, :edit, :update]
	before_filter :load_league_from_params, only: [:new, :create]

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