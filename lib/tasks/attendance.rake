namespace :attendance do
  
  desc 'Send attendance reminders for games happening in 3 days'
  task :send_reminders => :environment do
    target_date = Date.current + AttendanceMailer.notification_lead_time
    
    puts "Sending attendance reminders for games on #{target_date.strftime('%A, %B %e, %Y')}"
    
    result = AttendanceNotifier.send_attendance_reminders(target_date, 2)
    
    if result[:error]
      puts result[:error]
      next
    end
    
    puts "Found #{result[:total_users]} users who need attendance reminders"
    puts "Successfully sent #{result[:sent_count]} attendance reminder emails"
    
    if result[:errors].any?
      puts "Errors encountered:"
      result[:errors].each { |error| puts "  - #{error}" }
    end
  end
  
  desc 'Preview attendance reminders for games happening in 3 days (dry run)'
  task :preview_reminders => :environment do
    target_date = Date.current + AttendanceMailer.notification_lead_time
    
    puts "Preview: attendance reminders for games on #{target_date.strftime('%A, %B %e, %Y')}"
    
    result = AttendanceNotifier.collect_users_needing_reminders(target_date)
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
  
  desc 'Send Twilio Studio attendance reminder for a specific user'
  task :send_twilio_reminder, [:user_email] => :environment do |t, args|
    unless args.user_email
      puts "Usage: rake attendance:send_twilio_reminder[user@example.com]"
      exit
    end
    
    user = User.where(email_address: args.user_email).first
    unless user
      puts "User not found: #{args.user_email}"
      exit
    end
    
    puts "Triggering Twilio flow for #{user.name} (#{user.email_address})"
    
    result = AttendanceNotifier.send_sms_attendance_reminder(user)
    
    if result[:error]
      puts result[:error]
    else
      puts "Team: #{result[:team]}"
      puts "Date: #{result[:date]}"
      puts "Twilio flow triggered successfully: #{result[:execution_sid]}"
    end
  end
end