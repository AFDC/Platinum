class TestMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"

  def test_email(recipient_address)
    mail(to: recipient_address, subject: 'leagues.afdc.com email sending test')
  end
end
