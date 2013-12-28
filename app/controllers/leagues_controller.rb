class LeaguesController < ApplicationController
    before_filter :load_league_from_params, only: [:register, :registrations, :capture_payments]
    filter_access_to [:capture_payments], attribute_check: true

    def register
        if (Registration.where(league_id: @league._id, user_id: current_user._id).count > 0)
            redirect_to registrations_user_path(current_user), notice: "You've already registered for that league."
            return
        end

        @registration = Registration.new()
        @registration.league = @league
        @registration.user = current_user;
        render "registrations/edit"
    end

    def registrations
        @registrations = {}

        @registrations[:active] = Registration.where(league_id: @league._id, status: 'active')
        @registrations[:authorized] = Registration.where(league_id: @league._id, status: 'authorized')
        @registrations[:pending] = Registration.where(league_id: @league._id, status: 'pending')
        @registrations[:cancelled] = Registration.where(league_id: @league._id, status: 'cancelled')
    end

    def capture_payments
        @men = []
        @women = []
        @errors = []
        good_ids = []

        params[:reg_id].each do |reg_id|
            r = Registration.find(reg_id)
            

            if r
                if r.status == 'authorized'
                    @men << r if r.gender == 'male'
                    @women << r if r.gender == 'female'
                    good_ids << r._id.to_s
                else
                    @errors << "Payment not yet authorized for #{r.user.name}."
                end
            else
                @errors << "Registration not found for #{reg_id}"
            end
        end

        flash[:error] = "Errors were found in your submission, see below" if @errors.count > 0

        if params[:confirm] == '1' && @errors.count == 0
            good_ids.each do |reg_id|
                PaymentCaptureWorker.perform_async(reg_id)
            end
            redirect_to registrations_league_path(@league), notice: "#{@men.count + @women.count} registrations queued for capture, this may take some time."
        end
    end

    private

    def load_league_from_params
        begin
            @league = League.find(params[:id])
        rescue
            redirect_to leagues_path, flash: {error: "Could not load League for ID '#{params[:id]}', please try a different field."}
        end
    end
end
