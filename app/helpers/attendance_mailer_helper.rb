module AttendanceMailerHelper
  def rsvp_url(token)
    Rails.application.routes.url_helpers.attendance_token_url(
      token: token,
      host: ENV['MAILER_HOST'] || 'leagues.afdc.com'
    )
  end
end
