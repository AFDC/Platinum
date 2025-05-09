class WaiversController < ApplicationController
    before_filter :load_waiver_from_params, only: [:show, :edit, :update]

    def index
        @waivers = Waiver.all
    end

    def new
        @waiver = Waiver.new
    end

    def update
        if @waiver.update(update_waiver_params)
            redirect_to waivers_path
        else
            render :edit
        end
    end

    def create
        @waiver = Waiver.new(create_waiver_params)
        if @waiver.save
            redirect_to waivers_path
        else
            puts @waiver.errors.full_messages
            render :new
        end
    end

    def show
        render layout: "new_homepage"
    end

    private

    def load_waiver_from_params
        @waiver = Waiver.find(params[:id])

        if @waiver.nil?
            @waiver = Waiver.where(active: true, slug: params[:id]).first
        end

        if @waiver.nil?
            redirect_to home_path, flash: {notice: "That waiver does not exist or is no longer active."} and return
        end
end

    def update_waiver_params
        params.require(:waiver).permit(:name, :description, :slug, :active, :league_default, :signature_valid_for, :special_event)
    end

    def create_waiver_params
        params.require(:waiver).permit(:url).merge(update_waiver_params)
    end
end