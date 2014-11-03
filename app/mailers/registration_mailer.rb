class RegistrationMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def registration_active(registration_id)
    @registration = Registration.find(registration_id)
    @user = @registration.user
    @league = @registration.league

    mail(to: @registration.user.email_address, subject: '[AFDC] Welcome to ' + @league.name)
  end

  def registration_accepted(registration_id)
    @registration = Registration.find(registration_id)
    @user = @registration.user
    @league = @registration.league

    mail(to: @registration.user.email_address, subject: '[AFDC] Registration accepted for ' + @league.name)
  end

end
