class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:cancel, :edit, :update, :checkout, :approved, :canceled, :show, :pay, :donate, :waitlist_authorize]
    filter_access_to [:edit, :update, :show, :checkout, :cancel, :pay], attribute_check: true

    def create
        raise "This should not be possible."
    end

    def pay
        unless @registration.status == 'registering'
            message = "Can't pay for that registration; your current status is: '#{@registration.status}'."
            message = "You are already in that league, you don't need to pay again!" if @registration.status == 'active'
            message = "You have canceled your registration. Please contact help@afdc.com if you want to un-cancel." if @registration.status == 'canceled'
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

    def waitlist_authorize
        unless @registration.status == 'registering_waitlisted'
            message = "Can't authorize payment for that registration; your current status is: '#{@registration.status}'."
            message = "You are already in that league, you don't need to pay again!" if @registration.status == 'active'
            message = "You have canceled your registration. Please contact help@afdc.com if you want to un-cancel." if @registration.status == 'canceled'
            redirect_to registration_path(@registration), flash: {error: message} and return             
        end

        if @registration.is_expired?
            redirect_to register_league_path(@registration.league), flash: {error: "You took too long to register. Please try again."}
            return
        end

        # This player doesn't have to pay
        if @registration.league.comped? @registration.user
            @registration.waitlist
            redirect_to registration_path(@registration), notice: 'Your league dues will be comped. You are now on the waitlist.'
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
        status_types["waitlisted"]             = :edit

        reg_status_type = status_types[@registration.status]

        if reg_status_type == :invalid
            error_str = "'#{@registration.status}' is not a valid registration status."
            error_str = "Your registration seems to have expired -- please try again." if @registration.status == 'expired'

            redirect_to league_path(@registration.league), flash: {error: error_str}
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

        if @registration.waiver_signature.nil?
            sig = WaiverSignature.create_from_registration!(@registration)
            if sig.nil?
                Bugsnag.notify(StandardError.new("Failed to create waiver signature for registration #{@registration.id}"))
            end
        end

        log_audit('Register', league: @registration.league, registration: @registration)
        MailChimpWorker.perform_async(@registration.user._id.to_s, params[:subscribe])

        if @registration.status == "registering_waitlisted"
            redirect_to waitlist_authorize_registration_path(@registration)
            return
        end

        if @registration.league.comped?(@registration.user) == false && @registration.league.solicit_donations?
            redirect_to donate_registration_path(@registration)
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
        if reg_params[:pair_requested_user_id]
            pair_user_id = reg_params[:pair_requested_user_id].reject {|x| x.blank?}.first
            pc = PairingCoordinator.new(@registration.league)
            pc.request_pair(@registration.user, pair_user_id)
        end

        if permitted_to? :manage, @registration.league
            @registration.commish_rank = reg_params[:commish_rank]
        end
    end

    def load_registration_from_params
        begin
            @registration = Registration.find(params[:id])
            @league = @registration.league
        rescue
            redirect_to registrations_user_path(current_user), flash: {error: "Could not load registration for ID '#{params[:id]}'."}
        end
    end
end
