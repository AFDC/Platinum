class RegistrationGroupsController < ApplicationController
    before_filter :load_league_from_params
    before_filter :load_group_from_params, only: [:show, :edit, :update]
    filter_access_to [:edit, :update, :show], attribute_check: true

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
        redirect_to league_registration_groups_path(@league), notice: "#{@league.core_type.capitalize} Updated Successfully"
      else
        render :edit
      end
    end

    private

    def load_league_from_params
      @league = League.find(params[:league_id])

      redirect_to(leagues_path, flash: {error: "League not found."}) unless @league
      redirect_to(leagues_path, flash: {error: "Cores and pods are not enabled for #{@league.name}"}) unless @league.core_type.present?
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
