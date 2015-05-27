class SpiritReportsController < ApplicationController
    before_filter :load_report_object, only: [:new, :create]
    before_filter :load_report_by_id, only: [:edit, :update, :show]
    before_filter :validate_editor, only: [:create, :update]

    def new
        unless @report.new_record?
            redirect_to edit_spirit_report_path(@report)
        end
    end

    def edit
        render :new
    end

    def create
        update
    end

    def update
        @report.reporter = current_user

        if @report.update_attributes(report_params)
            redirect_to team_path(@opponent), notice: "Report filed successfully."
        else
            render :new
        end
    end


    private

    def load_report_by_id
        @report = SpiritReport.find(params[:id])
    end

    def validate_editor
        @opponent = @report.game.opponent_for(@report.team)
        unless @opponent[:captains].include? current_user._id
           redirect_to league_path(game.league), flash: {error: "You don't have permission to report that spirit score."}
        end        
    end

    def load_report_object
        game = Game.find(params[:game_id])
        if game.nil?
            redirect_to home_path, flash: {error: "Could not load Game for ID '#{params[:game_id]}', please try again."} 
            return
        end

        team = Team.find(params[:team_id])
        if team.nil?
            redirect_to league_path(game.league), flash: {error: "Could not find Team for ID '#{params[:team_id]}', plase try again."}
            return
        end

        unless game.team_ids.include? team.id
           redirect_to league_path(game.league), flash: {error: "Team with ID '#{params[:team_id]}' did not participate in that game, plase try again."}
        end

        @report = SpiritReport.find_or_initialize_by(game_id: game._id, team_id: team._id, league_id: game.league._id)
    end

    def report_params
        permitted_params = [:rules_score, :rules_comments, :fouls_score, :fouls_comments, :fairness_score, :fairness_comments, :attitude_score, :attitude_comments, :communication_score, :communication_comments]

        params.require(:spirit_report).permit(*permitted_params)
    end

end
