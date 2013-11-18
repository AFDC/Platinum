class LeaguesController < ApplicationController
    before_filter :load_league_from_params, only: [:register]

    def register
        if (Registration.where(league_id: @league._id, user_id: current_user._id).count > 0)
            redirect_to registrations_user_path(current_user), notice: "You've already registered for that league."
            return
        end

        @registration = Registration.new()
        @registration.league = @league
    end

    def load_league_from_params
        begin
            @league = League.find(params[:id])
        rescue
            redirect_to leagues_path, flash: {error: "Could not load League for ID '#{params[:id]}', please try a different field."}
        end
    end
end
