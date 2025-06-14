class PickupMailer < ActionMailer::Base
    default from: "system@leagues.afdc.com"
    layout 'zurb_ink_basic'

    def invite(pickup_registration_id)
        @pickup_registration = PickupRegistration.find(pickup_registration_id)

        @user = @pickup_registration.user
        @league = @pickup_registration.league
        @team = @pickup_registration.team

        @first_game = @pickup_registration.games.first

        mail(to: @user.email_address, subject: "[AFDC] Invitation to play as a pickup on #{@pickup_registration.assigned_date.strftime("%A, %B %e, %Y")} (ACTION REQUIRED)")
    end

    def confirm(pickup_registration_id)
        @pickup_registration = PickupRegistration.find(pickup_registration_id)

        recipients = [@pickup_registration.user.email_address] # The player picking up
        recipients += @pickup_registration.team.captains.map(&:email_address) # The team captains
        recipients += @pickup_registration.league.commissioners.map(&:email_address) # The league commissioners

        subject = "[AFDC] Confirming #{@pickup_registration.user.name} as a pickup player for #{@pickup_registration.team.name} on #{@pickup_registration.assigned_date.strftime("%A, %B %e, %Y")}"

        mail(to: recipients, subject: subject)
    end

    def decline(pickup_registration_id)
        @pickup_registration = PickupRegistration.find(pickup_registration_id)

        mail(to: @pickup_registration.league.commissioners.map(&:email_address), subject: "[AFDC] Pickup Invitation Declined for #{@pickup_registration.user.name}")
    end

    def cancel(pickup_registration_id, refund_processed = false)
        @pickup_registration = PickupRegistration.find(pickup_registration_id)
        @refund_processed = refund_processed

        @user = @pickup_registration.user
        @league = @pickup_registration.league
        @team = @pickup_registration.team

        recipients = [@user.email_address] # The player picking up
        recipients += @team.captains.map(&:email_address) # The team captains
        recipients += @league.commissioners.map(&:email_address) # The league commissioners

        subject = "[AFDC] Pickup Game Canceled for #{@user.name} - #{@pickup_registration.assigned_date.strftime("%A, %B %e, %Y")}"

        mail(to: recipients, subject: subject)
    end
end
