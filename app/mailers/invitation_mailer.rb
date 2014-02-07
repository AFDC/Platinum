class InvitationMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def pair_request(invitation_id)
    @invite = Invitation.find(invitation_id)
    @league = @invite.handler

    mail(to: @invite.recipient.email_address, subject: "[AFDC] Pair request from #{@invite.sender.name}")

    @invite.status = 'sent'
    @invite.save
  end

  def pair_request_result(invitation_id)
    @invite = Invitation.find(invitation_id)
    @league = @invite.handler

    mail(to: @invite.sender.email_address, subject: "[AFDC] Pair request to #{@invite.recipient.name} #{@invite.status}")
  end
end
