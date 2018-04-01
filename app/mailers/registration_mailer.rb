class RegistrationMailer < ActionMailer::Base
  default from: '"AFDC Leagues Site" <system@leagues.afdc.com>'
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

  def registration_waitlisted(registration_id)
    @registration = Registration.find(registration_id)
    @user = @registration.user
    @league = @registration.league

    mail(to: @registration.user.email_address, subject: "[AFDC] #{@league.name} Wait List")
  end

  def stale_accepted_registration(registration_id)
    @registration = Registration.find(registration_id)
    @user = @registration.user
    @league = @registration.league

    mail(to: @registration.user.email_address, subject: '[AFDC] Please pay for your ' + @league.name + ' registration before it expires!')
  end

  def unpaid_registration_canceled(registration_id)
    @registration = Registration.find(registration_id)
    @user = @registration.user
    @league = @registration.league

    mail(to: @registration.user.email_address, subject: '[AFDC] Your spot in ' + @league.name + ' has expired!')
  end
end
