namespace :attendance do
  # Helper method to collect users who need attendance reminders for a given date
  def self.collect_users_needing_reminders(target_date)
    # Find all games happening on the target date
    games = Game.where(
      :game_time.gte => target_date.beginning_of_day,
      :game_time.lt => target_date.end_of_day
    )
    
    return { games: games, users_to_remind: {} } if games.empty?
    
    # Collect all users who need reminders
    users_to_remind = {}
    
    games.each do |game|
      game.teams.each do |team|
        next unless team
        
        team.players.each do |player|
          # Check if player has attendance record for this date
          attendance = player.attendances.where(team: team, game_date: target_date).first
          
          unless attendance
            # Player needs a reminder
            users_to_remind[player._id] ||= { user: player, pending_games: [] }
            users_to_remind[player._id][:pending_games] << { team: team, game_date: target_date }
          end
        end
      end
    end
    
    { games: games, users_to_remind: users_to_remind }
  end
  
  desc 'Send attendance reminders for games happening in 3 days'
  task :send_reminders => :environment do
    target_date = Date.current + AttendanceMailer.notification_lead_time
    
    puts "Sending attendance reminders for games on #{target_date.strftime('%A, %B %e, %Y')}"
    
    result = collect_users_needing_reminders(target_date)
    games = result[:games]
    users_to_remind = result[:users_to_remind]
    
    if games.empty?
      puts "No games found for #{target_date.strftime('%A, %B %e, %Y')}"
      next
    end
    
    puts "Found #{games.count} games"
    puts "Found #{users_to_remind.count} users who need attendance reminders"
    
    # Send reminder emails grouped by user, team, and date
    sent_count = 0
    users_to_remind.each do |user_id, data|
      begin
        # Group user's pending games by team, then by date
        games_by_team = data[:pending_games].group_by { |pg| pg[:team] }
        
        games_by_team.each do |team, team_games|
          games_by_date = team_games.group_by { |pg| pg[:game_date] }
          
          games_by_date.each do |game_date, date_games|
            # Get all game IDs for this team on this date
            team_games_on_date = team.games.where(
              :game_time.gte => game_date.beginning_of_day,
              :game_time.lt => game_date.end_of_day
            )
            
            # Send one email per team per date
            AttendanceMailer.attendance_reminder(
              user_id, 
              team._id.to_s, 
              game_date.strftime('%Y-%m-%d'), 
              team_games_on_date.map(&:_id).map(&:to_s)
            ).deliver_now
            puts "Sent reminder to #{data[:user].name} for #{team.name} on #{game_date.strftime('%A, %B %e')}"
          end
        end
        
        sent_count += 1
        break if sent_count == 2
      rescue => e
        puts "Failed to send reminder to #{data[:user].name}: #{e.message}"
      end
    end
    
    puts "Successfully sent #{sent_count} attendance reminder emails"
  end
  
  desc 'Preview attendance reminders for games happening in 3 days (dry run)'
  task :preview_reminders => :environment do
    target_date = Date.current + AttendanceMailer.notification_lead_time
    
    puts "Preview: attendance reminders for games on #{target_date.strftime('%A, %B %e, %Y')}"
    
    result = collect_users_needing_reminders(target_date)
    games = result[:games]
    users_to_remind = result[:users_to_remind]
    
    if games.empty?
      puts "No games found for #{target_date.strftime('%A, %B %e, %Y')}"
      next
    end
    
    puts "Found #{games.count} games:"
    games.each do |game|
      puts "  - #{game.teams.first&.name} vs #{game.teams.last&.name} at #{game.game_time.strftime('%l:%M %P')}"
    end
    
    puts "\nWould send reminders to #{users_to_remind.count} users:"
    users_to_remind.each do |user_id, data|
      team_names = data[:pending_games].map { |pg| pg[:team].name }.join(', ')
      puts "  - #{data[:user].name} (#{data[:user].email_address}) for teams: #{team_names}"
    end
    
    puts "\nTo actually send these emails, run: rake attendance:send_reminders"
  end
end