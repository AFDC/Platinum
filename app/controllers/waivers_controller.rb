class WaiversController < ApplicationController
    before_filter :load_waiver_from_params, only: [:show, :edit, :update, :sign_waiver, :signatures]

    def index
        @waivers = Waiver.all
    end

    def signatures
        @signatures = @waiver.signatures.where(identity_verified: true).order_by(created_at: :desc)
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
        @current_signature = nil
        if current_user
            @current_signature = WaiverSignature.where(waiver: @waiver, user: current_user).first
        end

        render layout: "new_homepage"
    end

    def sign_waiver
        @user = current_user
        if current_user
            if params[:agreeCheckbox] == "yes"
                sig = WaiverSignature.new_from_user(current_user, @waiver)
                if sig.save
                    redirect_to waiver_signature_path(@waiver, sig), flash: {notice: "Waiver signed successfully."} and return
                else
                    redirect_to waiver_path(@waiver), flash: {notice: "There was an error signing the waiver. Please try again."} and return
                end
            else
                redirect_to waiver_path(@waiver), flash: {notice: "You must agree to the terms of the waiver to sign it."} and return
            end
        end

        raise "User not logged in"
        redirect_to home_path, flash: {notice: "Please log in to sign the waiver."}
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
        params.require(:waiver).permit(:name, :description, :slug, :active, :league_default, :signature_valid_for, :special_event, {admin_ids: []})
    end

    def create_waiver_params
        params.require(:waiver).permit(:url).merge(update_waiver_params)
    end
end