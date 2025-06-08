module ApplicationHelper
  def pending_attendance_games_for_user(user)
    return [] unless user
    
    # Find all teams the user is on
    user_teams = user.teams
    return [] if user_teams.empty?
    
    # Find games in the next 3 days
    start_date = Date.current
    end_date = Date.current + AttendanceMailer.notification_lead_time
    
    pending_games = []
    
    user_teams.each do |team|
      # Get upcoming game dates for this team
      game_dates = team.games.where(
        :game_time.gte => start_date.beginning_of_day,
        :game_time.lt => end_date.end_of_day
      ).map { |g| g.game_time.to_date }.uniq
      
      game_dates.each do |game_date|
        # Check if user has attendance record for this date
        attendance = user.attendances.where(team: team, game_date: game_date).first
        unless attendance
          pending_games << { team: team, game_date: game_date }
        end
      end
    end
    
    pending_games
  end

  def signed_attendance_url(user, team, game_date, attending)
    # Create signed token with user, team, date info, and timestamp
    token_data = {
      'user_id' => user._id.to_s,
      'team_id' => team._id.to_s,
      'game_date' => game_date.strftime('%Y-%m-%d'),
      'created_at' => Time.current.iso8601
    }
    
    token = Rails.application.message_verifier('attendance').generate(token_data)
    
    quick_update_team_attendances_url(team, token: token, attending: attending)
  end  
end
