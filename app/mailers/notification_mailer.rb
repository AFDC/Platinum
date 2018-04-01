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

  def games_canceled(notification_method_id, fieldsite_id, day_timestamp) 
    notification_method = NotificationMethod.find(notification_method_id)

    @user      = notification_method.user
    @fieldsite = FieldSite.find(fieldsite_id)
    @game_day  = Time.at(day_timestamp)

    mail(to: notification_method.target, subject: "AFDC Games Canceled for #{@game_day.strftime('%B %d, %Y')}")
  end
end
