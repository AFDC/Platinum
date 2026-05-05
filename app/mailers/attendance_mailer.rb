class AttendanceMailer < ActionMailer::Base
  default from: "system@leagues.afdc.com"
  layout 'zurb_ink_basic'

  def attendance_prompt(dispatch_id)
    @dispatch = AttendancePromptDispatch.find(dispatch_id)
    @user     = @dispatch.user
    @prompts  = @dispatch.prompts.map { |entry| AttendancePrompt.find(entry['prompt_id']) }
    @target   = @dispatch.target

    first_day = @prompts.map(&:game_day).min
    subject_date = first_day.strftime('%A, %B %-d')
    mail(
      to: @target,
      subject: "[AFDC] Will you be attending your games on #{subject_date}? (ACTION REQUIRED)"
    )
  end
end
