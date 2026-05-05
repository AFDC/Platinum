module AttendanceMailerHelper
  def rsvp_url(token)
    attendance_token_url(token: token)
  end
end
