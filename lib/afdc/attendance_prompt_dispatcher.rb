class AttendancePromptDispatcher
  def initialize(user:, prompts:, kind:)
    raise ArgumentError, "kind must be initial or reminder" unless %w(initial reminder).include?(kind)
    @user = user
    @prompts = prompts.sort_by(&:game_day)
    @kind = kind
  end

  def dispatch!
    # TRIAL — REMOVE BEFORE GA: when ATTENDANCE_RECIPIENT_ALLOWLIST is set,
    # only users whose email is in the comma-separated list actually get
    # SMS/email. Prompt records are still created upstream by the worker
    # (so the captain dashboard reflects reality), but this guard prevents
    # outbound messages to anyone not in the trial cohort.
    unless recipient_allowed?
      Rails.logger.info("AttendancePromptDispatcher: skipping outbound for #{@user.email_address} (not in ATTENDANCE_RECIPIENT_ALLOWLIST)")
      return
    end

    sms_targets = confirmed_sms_targets
    if sms_targets.any?
      sms_targets.each { |nm| send_sms_via(nm) }
      return
    end

    email_targets = resolve_email_targets
    return if email_targets == :opt_out
    Array(email_targets).each { |email| send_email_to(email) }
  end

  def sms_body
    header = "Hi #{@user.firstname}!"
    if @prompts.size == 1
      "#{header} #{single_line(@prompts.first, 1, with_codes: true)}"
    else
      lines = @prompts.each_with_index.map { |p, i| "(#{i + 1}) #{single_line(p, i + 1, with_codes: true)}" }
      "#{header} #{@prompts.size} AFDC game days to confirm: " + lines.join(' ')
    end
  end

  private

  # TRIAL — REMOVE BEFORE GA along with the guard in dispatch!.
  def recipient_allowed?
    list = ENV['ATTENDANCE_RECIPIENT_ALLOWLIST']
    return true if list.blank?
    allowed = list.split(',').map { |e| e.strip.downcase }
    allowed.include?(@user.email_address.to_s.downcase)
  end

  def single_line(prompt, index, with_codes: false)
    games = Game.where(:_id.in => prompt.game_ids).to_a.sort_by(&:game_time)
    day = prompt.game_day.strftime('%a %-m/%-d')
    first = games.first
    time = first ? first.game_time.strftime('%-l%P').sub('m', '') : ''
    site = first && first.field_site ? first.field_site.name : ''
    opp_team = first ? first.opponent_for(prompt.team) : nil
    opp = opp_team ? opp_team.name : ''
    base = "#{day} #{time} at #{site} vs #{opp}".strip
    return base unless with_codes
    if @prompts.size > 1
      "#{base} — Reply #{index}1 YES / #{index}2 NO / #{index}3 partial."
    else
      "#{base} Reply 11 for YES, 12 for NO, 13 for partial/notes."
    end
  end

  def confirmed_sms_targets
    @user.notification_methods.where(method: 'text', confirmed: true, enabled: true).to_a
  end

  def confirmed_email_targets
    @user.notification_methods.where(method: 'email', confirmed: true, enabled: true).to_a
  end

  def all_email_methods
    @user.notification_methods.where(method: 'email').to_a
  end

  def resolve_email_targets
    cems = confirmed_email_targets
    return cems.map(&:target) if cems.any?
    return :opt_out if all_email_methods.any?
    [@user.email_address]
  end

  def send_sms_via(notification_method)
    dispatch = AttendancePromptDispatch.create!(
      user: @user, channel: 'sms', sent_at: Time.now,
      kind: @kind, target: notification_method.target,
      prompts: prompts_payload
    )
    notification_method.send_text(sms_body)
    dispatch
  rescue StandardError => e
    Rails.logger.error("AttendancePromptDispatcher SMS failure for user #{@user._id}: #{e.message}")
    Bugsnag.notify(e) if defined?(Bugsnag)
    nil
  end

  def send_email_to(email)
    dispatch = AttendancePromptDispatch.create!(
      user: @user, channel: 'email', sent_at: Time.now,
      kind: @kind, target: email,
      prompts: prompts_payload
    )
    AttendanceMailer.attendance_prompt(dispatch._id.to_s).deliver
    dispatch
  rescue StandardError => e
    Rails.logger.error("AttendancePromptDispatcher email failure for user #{@user._id}: #{e.message}")
    Bugsnag.notify(e) if defined?(Bugsnag)
    nil
  end

  def prompts_payload
    @prompts.each_with_index.map { |p, i| { 'prompt_id' => p._id.to_s, 'prefix' => i + 1 } }
  end
end
