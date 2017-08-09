class FieldsController < ApplicationController
    layout "new_homepage"
    before_filter :load_fieldsite_from_params, only: [:show, :edit, :update]

    def index
        @fields = FieldSite.where(active: true)
    end

    def show
    end

    def load_fieldsite_from_params
        begin
            @field = FieldSite.find(params[:id])
        rescue
            redirect_to fields_path, flash: {error: "Could not load Field Site for ID '#{params[:id]}', please try a different field."}
        end
    end
end
