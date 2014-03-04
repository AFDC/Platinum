class RegistrationGroupsController < ApplicationController
    before_filter :load_league_from_params
    before_filter :load_group_from_params, only: [:show, :edit, :update, :add_to_team]
    filter_access_to [:edit, :update, :show, :add_to_team], attribute_check: true

    def index
      respond_to do |format|
        format.json do
          reg_groups = {}
          @league.registration_groups.each do |rg|
            reg_groups[rg._id] = {_id: rg[:_id], members: rg[:member_ids]}
          end

          render json: reg_groups
        end
        format.html do
        end
      end
    end

    def new
      @group = RegistrationGroup.new
    end

    def create
      @group = RegistrationGroup.new(group_params)
      @group.league = @league

      if @group.save
        redirect_to league_registration_groups_path(@league)
      else
        render :new
      end
    end

    def update
      if @group.update_attributes(group_params)
        redirect_to league_registration_groups_path(@league), notice: "#{@league.core_options.type.capitalize} updated successfully!"
      else
        render :edit
      end
    end

    def add_to_team
      unless params[:team_id] && target_team = Team.find(params[:team_id])
        redirect_to league_registration_groups_path(@league), flash: {error: "Could not find team #{params[:team_id]}"} and return
      end

      unless target_team.league == @league
        redirect_to league_registration_groups_path(@league), flash: {error: "League mismatch error!"} and return
      end

      processed = 0
      @group.members.each do |m|
        reg = @league.registration_for(m)
        next unless reg && reg.status == 'active'
        @league.add_player_to_team(m, target_team)
        processed += 1
      end

      redirect_to league_registration_groups_path(@league), notice: "Added #{processed} active players from that #{@league.core_options.type.capitalize} to #{target_team.name}."
    end

    private

    def load_league_from_params
      @league = League.find(params[:league_id])

      redirect_to(leagues_path, flash: {error: "League not found."}) unless @league
      redirect_to(leagues_path, flash: {error: "Cores and pods are not enabled for #{@league.name}"}) unless @league.core_options.type.present?
    end

    def load_group_from_params
      @group = RegistrationGroup.find(params[:id])

      redirect_to(league_registration_groups_path(@league), flash: {error: "Could not load Group for ID '#{params[:id]}'"}) unless @group
    end

    def group_params
        permitted_params = [{member_ids: []}, :notes]

        params.require(:registration_group).permit(*permitted_params)
    end
end
