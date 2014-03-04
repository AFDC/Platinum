class TeamMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def added_to_team(user_id, team_id)
    @user = User.find(user_id)
    @team = Team.find(team_id)

    mail(to: @user.email_address, subject: "[AFDC] You're now playing on '#{@team.name}' for #{@team.league.name}")
  end
end
