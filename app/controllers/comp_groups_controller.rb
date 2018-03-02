class CompGroupsController < ApplicationController
    layout "new_homepage"
    before_filter :load_group_from_params, only: [:show, :edit, :update]

    def new
        @group = CompGroup.new
    end

    def create
        @group = CompGroup.new(group_params)

        if @group.save
            redirect_to comp_groups_path, notice: "Group Created Successfully"
        else
            render :new
        end
    end

    def update
        if @group.update_attributes(group_params)
            redirect_to comp_groups_path, notice: "Group Updated Successfully"
        else
            render :edit
        end
    end


    private

    def load_group_from_params
        begin
            @group = CompGroup.find(params[:id])
        rescue
            redirect_to comp_groups_path, flash: {error: "Could not load Group for ID '#{params[:id]}', please try again."}
        end
    end

    def group_params
        permitted_params = [:name, :description, member_ids: []]

        params.require(:comp_group).permit(*permitted_params)
    end

end
