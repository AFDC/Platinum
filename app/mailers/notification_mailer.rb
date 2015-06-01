class NotificationMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def confirm_email(notification_method_id)
    @notification_method = NotificationMethod.find(notification_method_id)
    if @notification_method.method == 'email'
        @user = @notification_method.user
        
        mail(to: @notification_method.target, subject: 'AFDC Confirm Email')
    end
  end
end
