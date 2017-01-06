namespace :reports do
  desc 'Get a membership report'
  task :membership => :environment do
    headers = %w(sport league_id league_name team_id team_name user_id first_name last_name gender grank birthday)
    print CSV.generate_line headers

    League.each do |league|
        sport       = league.sport
        league_id   = league._id
        league_name = league.name

        league.teams.each do |team|
            team.players.each do |user|
                g_rank = league.registration_for(user).try(:g_rank)
                print CSV.generate_line [sport, league_id, league_name, team._id, team.name, user._id, user.firstname, user.lastname, user.gender, g_rank, user.birthdate]
            end
        end
    end
  end
end
