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

  desc 'List all users in the system'
  task :users => :environment do
    print CSV.generate_line %w(user_id first_name last_name email_address gender zip_code birthdate)

    User.each do |user|
      print CSV.generate_line [user._id, user.firstname, user.lastname, user.email_address, user.gender, user.postal_code, user.birthdate]
    end
  end

  desc 'List all leagues in the system'
  task :leagues => :environment do
    print CSV.generate_line %w(league_id name year sport season start_date end_date)

    League.each do |league|
      print CSV.generate_line [league._id, league.name, league.start_date.year, league.sport, league.season, league.start_date, league.end_date]
    end
  end

  desc 'List all teams in the system'
  task :teams => :environment do
    print CSV.generate_line %w(team_id league_id team_name captain_1 captain_2)

    Team.each do |team|
      captain_id_1 = team.captains[0].try(:_id)
      captain_id_2 = team.captains[1].try(:_id)

      print CSV.generate_line [team._id, team.league._id, team.name, captain_id_1, captain_id_2]
    end
  end

  desc 'List all league participants in the system'
  task :participants => :environment do
    headers = %w(league_id team_id user_id cored)
    print CSV.generate_line headers

    League.each do |league|
      league.teams.each do |team|
        team.players.each do |player|
          reg = league.registration_for(player)
          print CSV.generate_line [league._id, team._id, player._id, (reg.try(:cored?) ? 'y' : 'n')]
        end
      end
    end
  end

  desc 'List all game data in the system'
  task :games => :environment do
    print CSV.generate_line %w(game_id league_id field_id field_name team_id score rainout)

    Game.each do |game|
      game.teams.each do |team|
        print CSV.generate_line [game._id, game.league._id, game.fieldsite_id, game.field_site.name, team._id, game.score_for(team), (game.rained_out? ? 'y' : 'n')]
      end
    end
  end
end
