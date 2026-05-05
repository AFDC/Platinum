class AttendanceReplyParser
  SUFFIX_TO_STATUS = { 1 => 'yes', 2 => 'no', 3 => 'partial' }.freeze
  FUZZY_YES = %w(yes y yep yeah in coming).freeze
  FUZZY_NO  = %w(no n nope out cant can't).freeze

  Result = Struct.new(:kind, :resolved_prompts, :note_only_prompt)

  def self.parse(user:, body:)
    new(user: user, body: body.to_s.strip).parse
  end

  def initialize(user:, body:)
    @user = user
    @body = body
  end

  def parse
    anchor = AttendancePromptDispatch.latest_active_for_user(@user, channel: 'sms')
    return Result.new(:no_pending, [], nil) unless anchor

    codes = extract_codes(@body)

    if codes.any?
      return resolve_codes(anchor, codes)
    end

    pending = anchor.active_pending_prompts
    fuzzy = fuzzy_status(@body)
    if fuzzy && pending.size == 1
      prompt = pending.first
      prompt.record_response!(status: fuzzy, responded_by: @user, response_method: 'sms')
      return Result.new(:resolved, [prompt], nil)
    end

    target = pending.sort_by(&:created_at).last
    if target
      target.update_attributes!(note: @body)
      return Result.new(:note_only, [], target)
    end

    Result.new(:no_pending, [], nil)
  end

  private

  # Returns array of { code:, prefix:, suffix:, note: } in document order.
  def extract_codes(body)
    tokens = body.split(/\s+/)
    result = []
    i = 0
    while i < tokens.size
      if tokens[i] =~ /\A(\d)(\d)\z/
        prefix = $1.to_i
        suffix = $2.to_i
        note_parts = []
        j = i + 1
        while j < tokens.size && tokens[j] !~ /\A\d{2}\z/
          note_parts << tokens[j]
          j += 1
        end
        note = note_parts.join(' ').strip
        result << { code: tokens[i], prefix: prefix, suffix: suffix, note: note.empty? ? nil : note }
        i = j
      else
        i += 1
      end
    end
    result
  end

  def resolve_codes(anchor, codes)
    resolved = []
    codes.each do |c|
      next unless SUFFIX_TO_STATUS.key?(c[:suffix])
      prompt = anchor.prompt_for_prefix(c[:prefix])
      next unless prompt
      next unless AttendancePrompt.active_pending.where(_id: prompt._id).exists?
      prompt.record_response!(
        status: SUFFIX_TO_STATUS[c[:suffix]],
        responded_by: @user,
        response_method: 'sms',
        note: c[:note]
      )
      resolved << prompt
    end
    Result.new(resolved.any? ? :resolved : :unresolved_codes, resolved, nil)
  end

  def fuzzy_status(body)
    stripped = body.downcase.gsub(/[!.?,]/, '').strip
    return 'yes' if FUZZY_YES.include?(stripped)
    return 'no'  if FUZZY_NO.include?(stripped)
    nil
  end
end
