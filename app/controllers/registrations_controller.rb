class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:cancel, :edit, :update, :checkout, :approved, :canceled, :show, :pay]
    filter_access_to [:edit, :update, :show, :checkout, :cancel, :pay], attribute_check: true

    def create
        raise "This should not be possible."
    end

    def pay
        unless @registration.status == 'registering'
            message = "Can't pay for that registration; your current status is: '#{@registration.status}'."
            message = "You are already in that league, you don't need to pay again!" if @registration.status == 'active'
            message = "You have canceled your registration. Please contact help@afdc.com if you want to un-cancel." if @registration.status == 'canceled'
            message = "It's not your turn to register yet, so we can't accept your payment at this time." if @registration.status == 'queued'
            redirect_to registration_path(@registration), flash: {error: message} and return 
        end

        if @registration.is_expired?
            redirect_to register_league_path(@registration.league), flash: {error: "You took too long to register. Please try again."}
            return
        end

        # This player doesn't have to pay
        if @registration.league.comped? @registration.user
            @registration.comped = true
            @registration.activate!
            redirect_to registration_path(@registration), notice: 'Your league dues have been comped. You are now active in the league.'
            return
        end
    end

    def edit
    end

    def update
        status_types = Hash.new(:invalid)

        # Pending and Queued registrations shouldn't be able to be changed
        # Canceled and Expired registrations should get put back in the Queued state in leagues_controller#register

        status_types["registering"] = :new
        status_types["active"]      = :edit
        
        status_types["registering_waitlisted"] = :new
        status_types["waitlist"]             = :edit

        reg_status_type = status_types[@registration.status]

        if reg_status_type == :invalid
            redirect_to league_path(@registration.league), flash: {error: "'#{@registration.status}' is not a valid registration status."}
            return
        end

        if reg_status_type == :new
            unless @registration.league.registration_open_for?(current_user)
                redirect_to league_path(@registration.league), flash: {error: "The registrations for this league have either closed or haven't opened yet. Try again later!"}
                return
            end

            if @registration.is_expired?
                redirect_to register_league_path(@registration.league), flash: {error: "You took too long to register. Please try again."}
                return
            end

            @registration.signup_timestamp = Time.now
            @registration.paid = false
        end

        populate_registration

        if @registration.save == false
            render :edit
            return
        end

        if reg_status_type == :edit
            redirect_destination = registrations_user_path(current_user)
            redirect_destination = registrations_league_path(@registration.league) if @registration.user != current_user

            redirect_to redirect_destination, notice: "Update successful"
            return
        end

        log_audit('Register', league: @registration.league, registration: @registration)
        MailChimpWorker.perform_async(@registration.user._id.to_s, params[:subscribe])

        if @registration.status == "registering_waitlisted"
            @registration.update(status: "waitlist")
            RegistrationMailer.delay.registration_waitlisted(@registration._id.to_s)
            redirect_to league_path(@registration.league), notice: "You have been added to the waitlist."
            return
        end

        # If we get here, the user has successfully registered and now just needs to pay
        redirect_to pay_registration_path(@registration)
    end

    def show
    end

    def cancel
        if @registration.cancel
            log_audit('Cancel', league: @registration.league, registration: @registration)
            redirect_to registrations_user_path(@registration.user), notice: "Your registration has been canceled." and return
        end

        redirect_to registrations_user_path(@registration.user), flash: {error: "Cancelling your registration failed, please contact a league commissioner."}
    end

    private

    def populate_registration
        reg_params = params[:registration]

        @registration.memoize_user_info

        if reg_params[:waiver_accepted] == '1'
            @registration.waiver_acceptance_date = Time.now
        end

        if @registration.league.require_grank?
            @registration.g_rank_result = @registration.user.g_rank_results.first
            @registration.g_rank = @registration.g_rank_result.score
        end

        @registration.availability = {
            'general' => reg_params[:gen_availability],
            'attend_tourney_eos' => (reg_params[:eos_availability] == '1')
        }
        @registration.player_strength = reg_params[:player_strength]

        if @registration.league.self_rank_type == "simple"
            @registration.self_rank = reg_params[:self_rank]
        end

        if @registration.league.self_rank_type == "detailed"
            dsr = {
                "experience" => reg_params[:self_rank_experience],
                "athleticism" => reg_params[:self_rank_athleticism],
                "skills" => reg_params[:self_rank_skills]
            }

            # Ensure these are numbers or nil
            dsr.keys.each do |k|
                if (dsr[k] == "")
                   dsr[k] = nil
                end

                dsr[k] = dsr[k].try(:to_i)
            end

            @registration.detailed_self_rank = dsr
        end

        @registration.notes = reg_params[:notes]
        @registration.shirt_size = reg_params[:shirt_size]
        if reg_params[:pair_id]
            @registration.pair_id = reg_params[:pair_id].first
        end

        if permitted_to? :manage, @registration.league
            @registration.commish_rank = reg_params[:commish_rank]
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
