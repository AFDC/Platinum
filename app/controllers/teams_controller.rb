class TeamsController < ApplicationController
	filter_access_to [:edit_avatar, :update_avatar, :destroy_avatar], :attribute_check => true
	before_filter :load_team_from_params, only: [:show, :edit, :update]

	def index
		@team_list = []
		if (params[:query])
			@team_list = Team.where({name: /#{params[:query]}/i})
		end
	end

	def show
	end

	def edit
	end

	def update
		@team.update_attributes(team_params)
		redirect_to team_path(@team), notice: 'Team Updated!'
	end

	private

	def load_team_from_params
		begin
			@team = Team.find(params[:id])
		rescue
			redirect_to teams_path, flash: {error: "Could not load team for ID '#{params[:id]}', please try a different team."}
		end
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