class DashboardController < ApplicationController
  def homepage
    @leagues_registering = League.current.to_a.select{|l| l.registration_open? }
    @leagues_running = League.current.to_a.select{|l| l.started? }
    @your_teams = []

    if current_user && current_user[:teams].present?
      team_ids = League.current.collect(&:team_ids).flatten & current_user[:teams]

      team_ids.each do |tid|
        @your_teams << Team.find(tid)
      end
    end
  end
end
