class WaiverMailer < ActionMailer::Base
    default from: "system@leagues.afdc.com"
    layout 'zurb_ink_basic'
  
    def confirm_identity(waiver_signature_id)
        @waiver_signature = WaiverSignature.find(waiver_signature_id)
        mail(to: @waiver_signature.email, subject: 'AFDC Waiver Agreement Confirmation')
    end

    def waiver_completed(waiver_signature_id)
        @waiver_signature = WaiverSignature.find(waiver_signature_id)
        mail(to: @waiver_signature.email, subject: 'AFDC Waiver Agreement Signed')
    end
  
  end
  