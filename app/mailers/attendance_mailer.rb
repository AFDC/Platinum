class AttendanceMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'
  add_template_helper(ApplicationHelper) 

  def self.notification_lead_time
    3.days
  end
  
  def attendance_reminder(user_id, team_id, game_date, game_ids)
    @user = User.find(user_id)
    @team = Team.find(team_id)
    @game_date = Date.parse(game_date) if game_date.is_a?(String)
    @game_date = game_date if game_date.is_a?(Date)
    @pending_games = Game.find(game_ids)
    
    mail(
      to: @user.email_address,
      subject: "[AFDC] Will you be attending your games on #{@game_date.strftime("%A, %B %e, %Y")}? (ACTION REQUIRED)"
    )
  end
end
