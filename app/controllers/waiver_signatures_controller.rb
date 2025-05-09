class WaiverSignaturesController < ApplicationController
    before_filter :load_waiver_from_params

    def show
        @signature = @waiver.signatures.find(params[:id])

        render layout: 'new_homepage'
    end
    
    private
    
    def load_waiver_from_params
        @waiver = Waiver.find(params[:waiver_id])

        if @waiver.nil?
            @waiver = Waiver.where(active: true, slug: params[:waiver_id]).first
        end

        if @waiver.nil?
            redirect_to home_path, flash: {notice: "That waiver does not exist or is no longer active."} and return
        end
    end
end