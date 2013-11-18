class LeaguesController < ApplicationController
    before_filter :load_league_from_params, only: [:register]

    def register
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
