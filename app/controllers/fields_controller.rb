class FieldsController < ApplicationController
    before_filter :load_fieldsite_from_params, only: [:show, :edit, :update]

    def index
        @fields = FieldSite.where(active: true)
    end

    def show
        if @field.nil?
            redirect_to fields_path, flash: {error: "Could not load Field Site for ID '#{params[:id]}', please try a different field."}
            return
        end
    end

    def load_fieldsite_from_params
        @field = FieldSite.find(params[:id])
    end
end
