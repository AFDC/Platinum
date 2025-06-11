class GameCancellationWorker
  include Sidekiq::Worker

  def perform(league_id, fieldsite_id, start_ts, end_ts, cancelling_user_id, notify = :nobody)
    league = League.find(league_id)
    raise "League not found for #{league_id}" unless league.present?

    @fieldsite = FieldSite.find(fieldsite_id)
    raise "Field Site not found for #{fieldsite_id}" unless @fieldsite.present?

    user = User.find(cancelling_user_id)
    raise "User not found for #{cancelling_user_id}" unless user

    notify = notify.to_sym

    games_to_cancel = league.games.where(field_site: @fieldsite, :game_time.gte => start_ts, :game_time.lte => end_ts)

    new_score_report = {
        reporter_id: user._id,
        report_time: 1.minute.ago,
        reporter_ip: '0.0.0.4',
        rainout: true,
        forfeit: false
    }

    teams = {}
    games_to_cancel.each do |game|
        next if game.rained_out?
        game.scores = new_score_report
        game.save
        game.teams.each do |t|
            teams[t._id] ||= t unless notify == :nobody
        end
    end

    return if notify == :nobody
    player_list = {}
    pickup_players = {}
    
    teams.each do |team_id, team|
        if notify == :captains
            team.captains.each do |u|
                player_list[u._id] ||= u
            end
            next
        end

        if notify == :whole_team
            team.players.each do |u|
                player_list[u._id] ||= u
            end
            next
        end
    end

    # Find pickup players for canceled games
    canceled_game_dates = games_to_cancel.map { |game| game.game_time.to_date }.uniq
    canceled_game_dates.each do |game_date|
        team_ids = teams.keys
        pickup_registrations = PickupRegistration.where(
            assigned_date: game_date,
            team_id: { '$in' => team_ids },
            status: 'accepted'
        )
        
        pickup_registrations.each do |pickup_reg|
            user = pickup_reg.user
            pickup_players[user._id] = {
                user: user,
                pickup_registration: pickup_reg,
                team: pickup_reg.team,
                refunded: false
            }
            
            # Attempt to refund if player paid
            if pickup_reg.paid? && !pickup_reg.is_comped?
                begin
                    pickup_reg.refund!
                    pickup_players[user._id][:refunded] = true
                rescue StandardError => e
                    # Log the error but continue with notifications
                    Rails.logger.error "Failed to refund pickup registration #{pickup_reg._id}: #{e.message}"
                end
            end
        end
    end

    game_date     = Time.at(start_ts).strftime('%a, %b %e')
    text_message  = "Bad news! Your AFDC games at #{@fieldsite.name} are canceled for (#{game_date})."

    player_list.each do |user_id, p|
        notify_user(p, text_message, start_ts)
    end
    
    # Notify pickup players with their team context and refund info
    pickup_players.each do |user_id, pickup_info|
        refund_text = pickup_info[:refunded] ? " Your pickup fee has been refunded." : ""
        pickup_text_message = "Bad news! Your AFDC game with #{pickup_info[:team].name} at #{@fieldsite.name} is canceled for (#{game_date}).#{refund_text}"
        notify_user(pickup_info[:user], pickup_text_message, start_ts)
    end
  end

  def notify_user(user, text_message, game_day_timestamp)
    user.notification_methods.each do |nm|
        next unless nm.enabled?

        if nm.method == 'text'
            nm.send_text(text_message)
        end

        if nm.method == 'email'
            NotificationMailer.games_canceled(nm._id, @fieldsite._id, game_day_timestamp).deliver
        end
    end
  end
end
