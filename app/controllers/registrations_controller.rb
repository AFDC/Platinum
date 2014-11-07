class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:cancel, :edit, :update, :checkout, :approved, :cancelled, :show, :pay]
    filter_access_to [:edit, :update, :show, :checkout, :cancel, :pay], attribute_check: true

    def create
        # reg_params = params[:registration]
        if League.find(params[:registration][:league_id]).registration_for(current_user)
            redirect_to registrations_user_path(current_user), flash: {error: "You have already registered for this league. Please be patient. There is no need to submitt he same form multiple times. Thank you."} and return
        end
        populate_registration Registration.new
    end

    def pay
        unless @registration.status == 'accepted'
            message = "You can only pay for your registration if it has been accepted into the league. Your current status is: '#{@registration.status}'."
            message = "You are already in that league, you don't need to pay again!" if @registration.status == 'active'
            message = "You have cancelled your registration. Please contact the webmaster if you want to un-cancel." if @registration.status == 'canceled'
            message = "You haven't been accepted into the league yet, so we can't accept your payment at this time." if @registration.status == 'pending'
            redirect_to registration_path(@registration), flash: {error: message} and return 
        end
    end

    def edit
    end

    def update
        populate_registration @registration
    end

    def show
    end

    def cancel
        if @registration.void_authorization
            redirect_to registrations_user_path(@registration.user), notice: "Your registration has been cancelled." and return
        end

        redirect_to registrations_user_path(@registration.user), flash: {error: "Cancelling your registration failed."}
    end

    private

    def populate_registration(reg)
        reg_params = params[:registration]

        if reg.new_record?
            reg.waiver_acceptance_date = Time.now
            reg.league = League.find(reg_params[:league_id])
            reg.signup_timestamp = Time.now
            reg.user = current_user
            reg.status = 'pending'
            reg.paid = false
        end

        unless ['25%', '50%', '75%', '100%'].include?(reg_params[:gen_availability])
            redirect_to register_league_path(reg.league), notice: "You must select and attendance percentage"
            return
        end

        if reg.league.allow_self_rank?
            unless ['1', '2', '3', '4', '5', '6', '7', '8', '9'].include?(reg_params[:self_rank])
                redirect_to register_league_path(reg.league), notice: "You must select a rank for yourself"
                return
            end
        end

        unless ['Runner', 'Thrower', 'Both'].include?(reg_params[:player_strength])
            redirect_to register_league_path(reg.league), notice: "You must select a primary role"
            return
        end

        unless reg_params[:waiver_accepted] == '1' || reg.persisted?
            redirect_to register_league_path(reg.league), notice: "You must accept the waiver to register"
            return
        end

        if reg.league.require_grank?
            reg.g_rank_result = reg.user.g_rank_results.first
            reg.g_rank = reg.g_rank_result.score
        end

        reg.availability = {
            general: reg_params[:gen_availability],
            attend_tourney_eos: (reg_params[:eos_availability] == '1')
        }
        reg.gender = reg.user.gender
        reg.player_strength = reg_params[:player_strength]
        reg.self_rank = reg_params[:self_rank]
        reg.notes = reg_params[:notes]
        if reg_params[:pair_id]
            reg.pair_id = reg_params[:pair_id].first
        end
        reg.user_data = {
            birthdate: reg.user.birthdate,
            firstname: reg.user.firstname,
            middlename: reg.user.middlename,
            lastname: reg.user.lastname,
            gender: reg.user.gender,
            height: reg.user.height,
            weight: reg.user.weight
        }

        if permitted_to? :manage, reg.league
            reg.commish_rank = reg_params[:commish_rank]
        end

        if reg.league.comped? reg.user
            reg.status = 'active'
            reg.comped = true
            flash_message = 'Your registration has been comped' if reg.new_record?
        end

        if reg.save
            if reg.user != current_user
                redirect_to registrations_league_path(reg.league), notice: "Update successful"
            else
                if reg.status == 'active' || reg.status == 'accepted' || current_user._id != reg.user._id
                    redirect_to league_path(reg.league), notice: flash_message || 'Update successful'
                else
                    redirect_to registrations_user_path(current_user)
                end
            end
        else
            render :edit
        end

    end

    def load_registration_from_params
        begin
            @registration = Registration.find(params[:id])
        rescue
            redirect_to registrations_user_path(current_user), flash: {error: "Could not load registration for ID '#{params[:id]}'."}
        end
    end
end
