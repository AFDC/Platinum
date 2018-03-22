class DashboardController < ApplicationController
  def homepage
    @league_list = League.not_ended
    @your_teams = []
    team_ids    = []

    if current_user && current_user[:teams].present?
      team_ids = @league_list.collect(&:team_ids).flatten & current_user[:teams]

      team_ids.each do |tid|
        @your_teams << Team.find(tid)
      end
    end

    @league_games = []
    @your_games   = []

    Game.where(game_time: {'$gte' => 90.minutes.ago, '$lte' => Date.today.end_of_day}).each do |g|
      if (g[:teams] & team_ids).empty?
        @league_games << g
      else
        @your_games << g
      end
    end

    render layout: "new_homepage"
  end

  def audit_logs
    @logs = AuditLog.order_by(_id: 'desc').limit(1000)
  end
end
