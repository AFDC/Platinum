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
        if params[:waiver_signature_id].present?
            sig = WaiverSignature.find(params[:waiver_signature_id])

            if sig.nil?
                redirect_to waiver_path(@waiver), flash: {notice: "Invalid waiver signature."} and return
            end

            if sig.confirmation_code == params[:confirmationCode]
                sig.update(
                    identity_verified: true, 
                    identity_verification_timestamp: Time.now,
                    identity_verification_method: "email"
                )
                redirect_to waiver_signature_path(@waiver, sig), flash: {notice: "Waiver signed successfully."} and return
            else
                redirect_to waiver_signature_path(@waiver, sig), flash: {error: "Invalid confirmation code."} and return
            end
        end

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

        if params[:guestName].present? && params[:guestEmail].present?
            sig = WaiverSignature.new(
                name: params[:guestName],
                email: params[:guestEmail],
                waiver: @waiver,
                confirmation_code: Waiver.generate_confirmation_code
            )
            if sig.save
                WaiverMailer.delay.confirm_identity(sig._id.to_s)
                redirect_to waiver_signature_path(@waiver, sig), flash: {notice: "Waiver signed successfully."} and return
            end
            
            redirect_to waiver_path(@waiver), flash: {notice: "There was an error."} and return
        end
        
        redirect_to waiver_path(@waiver), flash: {notice: "Please enter your name and email address to sign the waiver."} and return
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