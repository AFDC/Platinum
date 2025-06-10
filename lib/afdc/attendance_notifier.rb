class AttendanceNotifier
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
  
  def self.send_attendance_reminders(target_date = nil, limit = nil)
    target_date ||= Date.current + AttendanceMailer.notification_lead_time
    
    result = collect_users_needing_reminders(target_date)
    games = result[:games]
    users_to_remind = result[:users_to_remind]
    
    return { sent_count: 0, error: "No games found for #{target_date.strftime('%A, %B %e, %Y')}" } if games.empty?
    
    # Send reminder emails grouped by user, team, and date
    sent_count = 0
    errors = []
    
    users_to_remind.each do |user_id, data|
      break if limit && sent_count >= limit
      
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
          end
        end
        
        sent_count += 1
      rescue => e
        errors << "Failed to send reminder to #{data[:user].name}: #{e.message}"
      end
    end
    
    { sent_count: sent_count, total_users: users_to_remind.count, errors: errors }
  end
  
  def self.send_sms_attendance_reminder(user, team = nil, game_date = nil)
    # Check if user has unsubscribed from SMS notifications
    if user.unsubscribed_from_attendance_sms
      return { error: "User #{user.name} has unsubscribed from attendance SMS notifications" }
    end
    
    # Find user's next pending game if not specified
    if team.nil? || game_date.nil?
      pending_game = find_next_pending_attendance_for_user(user)
      return { error: "No pending attendance found for #{user.name}" } if pending_game.nil?
      
      team = pending_game[:team]
      game_date = pending_game[:game_date]
    end
    
    # Get games for this date
    team_games_on_date = team.games.where(
      :game_time.gte => game_date.beginning_of_day,
      :game_time.lt => game_date.end_of_day
    )
    
    begin
      execution_sid = trigger_twilio_attendance_flow(user, team, game_date, team_games_on_date)
      { success: true, execution_sid: execution_sid, team: team.name, date: game_date.strftime('%A, %B %e, %Y') }
    rescue => e
      { error: "Failed to trigger Twilio flow: #{e.message}" }
    end
  end
  
  def self.trigger_twilio_attendance_flow(user, team, game_date, games = [])
    require 'twilio-ruby'
    
    # Twilio credentials (should be in environment variables)
    account_sid = ENV['twilio_sid']
    auth_token = ENV['twilio_token']
    flow_sid = ENV['twilio_attendance_flow_sid']
    
    unless account_sid && auth_token && flow_sid
      raise "Missing Twilio credentials. Set twilio_sid, twilio_token, and twilio_attendance_flow_sid"
    end
    
    # Initialize Twilio client
    client = Twilio::REST::Client.new(account_sid, auth_token)
    
    # Generate signed tokens for webhook responses
    yes_token = generate_attendance_token(user, team, game_date, true)
    no_token = generate_attendance_token(user, team, game_date, false)
    unsub_token = generate_unsubscribe_token(user)
    
    flow_parameters = {
      'user_name' => user.firstname,
      'team_id' => team._id.to_s,
      'friendly_game_date' => game_date.strftime('%A, %B %e'),
      'game_date' => game_date.strftime('%Y-%m-%d'),
      'yes_token' => yes_token,
      'no_token' => no_token,
      'unsub_token' => unsub_token
    }
    
    # Create Studio flow execution using the SDK
    execution = client.studio.v2.flows(flow_sid).executions.create(
      to: "+1#{user.notification_methods.where(method: "text").first.target}",
      from: ENV['twilio_number'],
      parameters: flow_parameters
    )
    
    return execution.sid
  end
  
  def self.generate_attendance_token(user, team, game_date, attending)
    token_data = {
      'user_id' => user._id.to_s,
      'team_id' => team._id.to_s,
      'game_date' => game_date.strftime('%Y-%m-%d'),
      'attending' => attending,
      'created_at' => Time.current.iso8601
    }
    
    Rails.application.message_verifier('twilio_attendance').generate(token_data)
  end
  
  def self.generate_unsubscribe_token(user)
    token_data = {
      'user_id' => user._id.to_s,
      'action' => 'unsubscribe',
      'created_at' => Time.current.iso8601
    }
    
    Rails.application.message_verifier('twilio_attendance').generate(token_data)
  end
  
  private
  
  def self.find_next_pending_attendance_for_user(user)
    target_date = Date.current + AttendanceMailer.notification_lead_time
    pending_games = []
    
    user.teams.each do |team|
      game_dates = team.games.where(
        :game_time.gte => Date.current.beginning_of_day,
        :game_time.lt => target_date.end_of_day
      ).map { |g| g.game_time.to_date }.uniq
      
      game_dates.each do |game_date|
        attendance = user.attendances.where(team: team, game_date: game_date).first
        unless attendance
          pending_games << { team: team, game_date: game_date }
        end
      end
    end
    
    return nil if pending_games.empty?
    
    # Return the earliest pending game
    pending_games.sort_by { |pg| pg[:game_date] }.first
  end
end