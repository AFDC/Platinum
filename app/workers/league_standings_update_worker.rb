class LeagueStandingsUpdateWorker
  include Sidekiq::Worker

  def perform(league_id)
    league = League.find(league_id)
    raise "League not found for #{league_id}" unless league

    league.update_standings!
  end
end
