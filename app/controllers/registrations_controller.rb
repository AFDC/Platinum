class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:cancel, :edit, :update, :checkout, :approved, :cancelled, :show, :pay]
    filter_access_to [:edit, :update, :show, :checkout, :cancel, :pay], attribute_check: true

    def create
        league = League.find(params[:registration][:league_id])

        # reg_params = params[:registration]
        if league.registration_for(current_user)
            redirect_to registrations_user_path(current_user), flash: {error: "You have already registered for this league. Please be patient. There is no need to submitt he same form multiple times. Thank you."} and return
        end
        unless league.registration_open_for?(current_user)
            redirect_to league_path(league), flash: {error: "The registrations for this league have either closed or haven't opened yet. Try again later!"} and return
        end
        @registration = Registration.new
        populate_registration
    end

    def pay
        unless @registration.status == 'accepted'
            message = "You can only pay for your registration if it has been accepted into the league. Your current status is: '#{@registration.status}'."
            message = "You are already in that league, you don't need to pay again!" if @registration.status == 'active'
            message = "You have cancelled your registration. Please contact help@afdc.com if you want to un-cancel." if @registration.status == 'canceled'
            message = "You haven't been accepted into the league yet, so we can't accept your payment at this time." if @registration.status == 'pending'
            redirect_to registration_path(@registration), flash: {error: message} and return 
        end
    end

    def edit
    end

    def update
        populate_registration
    end

    def show
    end

    def cancel
        if @registration.cancel
            redirect_to registrations_user_path(@registration.user), notice: "Your registration has been cancelled." and return
        end

        redirect_to registrations_user_path(@registration.user), flash: {error: "Cancelling your registration failed, please contact a league commissioner."}
    end

    private

    def populate_registration
        reg_params = params[:registration]

        if @registration.new_record?
            @registration.league = League.find(reg_params[:league_id])
            @registration.signup_timestamp = Time.now
            @registration.user = current_user
            @registration.status = 'pending'
            @registration.paid = false
        end

        if reg_params[:waiver_accepted] == '1'
            @registration.waiver_acceptance_date = Time.now
        end

        if @registration.league.require_grank?
            @registration.g_rank_result = @registration.user.g_rank_results.first
            @registration.g_rank = @registration.g_rank_result.score
        end

        @registration.availability = {
            general: reg_params[:gen_availability],
            attend_tourney_eos: (reg_params[:eos_availability] == '1')
        }
        @registration.gender = @registration.user.gender
        @registration.player_strength = reg_params[:player_strength]
        @registration.self_rank = reg_params[:self_rank]
        @registration.notes = reg_params[:notes]
        if reg_params[:pair_id]
            @registration.pair_id = reg_params[:pair_id].first
        end
        @registration.user_data = {
            birthdate: @registration.user.birthdate,
            firstname: @registration.user.firstname,
            middlename: @registration.user.middlename,
            lastname: @registration.user.lastname,
            gender: @registration.user.gender,
            height: @registration.user.height,
            weight: @registration.user.weight
        }

        if permitted_to? :manage, @registration.league
            @registration.commish_rank = reg_params[:commish_rank]
        end

        if @registration.save
            MailChimpWorker.perform_async(@registration.user._id.to_s, params[:subscribe])
            if @registration.user != current_user
                redirect_to registrations_league_path(@registration.league), notice: "Update successful"
            else
                if @registration.status == 'active' || @registration.status == 'accepted' || current_user._id != @registration.user._id
                    redirect_to league_path(@registration.league), notice: flash_message || 'Update successful'
                else
                    redirect_to registrations_user_path(current_user), notice: "You have registered successfully! You'll be notified if you are accepted into the league and will pay at that time."
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
