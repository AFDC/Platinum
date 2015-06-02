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
        report_time: Time.now,
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

    game_date     = Time.at(start_ts).strftime('%a, %b %e')
    text_message  = "Bad news! Your AFDC games at #{@fieldsite.name} are cancelled for today (#{game_date})."

    player_list.each do |user_id, p|
        notify_user(p, text_message, start_ts)
    end
  end

  def notify_user(user, text_message, game_day_timestamp)
    user.notification_methods.each do |nm|
        next unless nm.enabled?

        if nm.method == 'text'
            twilio_client = Twilio::REST::Client.new
            twilio_client.account.messages.create({ 
                from: ENV['twilio_number'], 
                to:   nm.target,
                body: text_message
            })
        end

        if nm.method == 'email'
            NotificationMailer.games_cancelled(nm._id, @fieldsite._id, game_day_timestamp).deliver
        end
    end
  end
end
