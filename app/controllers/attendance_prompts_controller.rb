class AttendancePromptsController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: [:sms_webhook]
  before_filter :load_prompt_from_token, only: [:show, :update]

  def sms_webhook
    phone = digits_only(params[:From])
    body  = params[:Body].to_s

    nm = NotificationMethod.where(method: 'text', target: phone).first
    if nm.nil? || nm.user.nil?
      return render_twiml("We don't recognize this number. Visit https://leagues.afdc.com to manage your notifications.")
    end

    user = nm.user
    result = AttendanceReplyParser.parse(user: user, body: body)

    case result.kind
    when :no_pending
      render_twiml("No active attendance questions right now. Visit https://leagues.afdc.com for your schedule.")
    when :resolved
      render_twiml("Got it — thanks! (#{result.resolved_prompts.size} answered.)")
    when :unresolved_codes
      render_twiml("Sorry, I couldn't match that. Reply with the codes from the most recent message, or visit https://leagues.afdc.com.")
    when :note_only
      link = attendance_token_url(token: result.note_only_prompt.web_token, host: request.host, protocol: 'https')
      render_twiml("Got your note — to set yes/no/partial, visit #{link}.")
    end
  end

  def show
    if @prompt.game_day < Date.current
      render :show_passed and return
    end
    @games = Game.where(:_id.in => @prompt.game_ids).to_a.sort_by(&:game_time)
  end

  def update
    status = params[:status].to_s
    unless AttendancePrompt::STATUSES.include?(status) && status != 'pending'
      return render text: 'Invalid status', status: 422
    end
    @prompt.record_response!(
      status: status,
      responded_by: @prompt.user,
      response_method: 'web',
      note: params[:note]
    )
    redirect_to attendance_token_path(@prompt.web_token), notice: 'Thanks — your response is recorded.'
  end

  private

  def load_prompt_from_token
    @prompt = AttendancePrompt.where(web_token: params[:token]).first
    head 404 unless @prompt
  end

  def digits_only(s)
    digits = s.to_s.gsub(/\D/, '')
    digits = digits.sub(/\A1/, '') if digits.length == 11
    digits
  end

  def render_twiml(text)
    twiml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Message>#{ERB::Util.html_escape(text)}</Message></Response>"
    render text: twiml, content_type: 'text/xml'
  end
end
