class UserMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def password_reset(user_id, new_password)
    @user = User.find(user_id)
    @new_pw = new_password
    
    mail(to: @user.email_address, subject: 'AFDC League Manager Password Reset')
  end
end
