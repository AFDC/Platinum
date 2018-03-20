class DashboardController < ApplicationController
  def homepage
    @leagues_registering = League.not_started.to_a.select{|l| l.registration_open? }
    @leagues_running = League.started.to_a.select{|l| l.started? }
    @your_teams = []
    team_ids    = []

    if current_user && current_user[:teams].present?
      team_ids = League.not_ended.collect(&:team_ids).flatten & current_user[:teams]

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
end
