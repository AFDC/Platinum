class GamesController < ApplicationController
    filter_access_to [:edit_score, :update_score], :attribute_check => true
    before_filter :load_game_from_params, only: [:edit_score, :update_score, :show, :edit, :update]

    def index
    end

    def show
    end

    def edit
    end

    def update
    end

    def edit_score
        respond_to do |format|
            format.html { render :layout => !request.xhr? }
        end
    end

    def update_score
        old_score_report = @game.scores
        new_score_report = {
            reporter_id: current_user._id,
            report_time: Time.now,
            reporter_ip: request.remote_ip,
            rainout: false,
            forfeit: false
        }

        new_score_report['rainout'] = true if params[:rainout]

        if params['forfeit']
            new_score_report[:forfeit] = true
            @game.winner = BSON::ObjectId.from_string(params['forfeit'])
        end

        if params['score']
            top_score = -1
            params['score'].keys.each do |team_id|
                this_score = params['score'][team_id].to_i
                new_score_report[team_id] = this_score
                if this_score > top_score
                    top_score = this_score
                    @game.winner = BSON::ObjectId.from_string(team_id)
                elsif this_score == top_score
                    @game.winner = nil
                end

                new_score_report[team_id]
            end
        end

        @game.scores = new_score_report
        @game.old_scores << old_score_report if old_score_report.present?

        @game.save

        new_score_report[:winner] = @game.winner
        new_score_report[:game_id] = @game._id
        new_score_report[:team_ids] = @game.team_ids

        render text: new_score_report.to_json
    end

    private

    def load_game_from_params
        begin
            @game = Game.find(params[:id])
        rescue
            redirect_to schedules_path, flash: {error: "Could not load game for ID '#{params[:id]}'."}
        end
    end
end
