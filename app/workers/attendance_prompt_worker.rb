class AttendancePromptWorker
  include Sidekiq::Worker

  INITIAL_LEAD_DAYS  = 4
  REMINDER_LEAD_DAYS = 2

  # Quiet hours: do not generate or dispatch prompts between 9pm and 9am local
  # (Eastern). The hourly cron still ticks during this window, but the worker
  # short-circuits so players don't get a midnight buzz.
  QUIET_HOURS_START = 21  # inclusive (9pm)
  QUIET_HOURS_END   = 9   # exclusive (9am)

  def perform
    return if quiet_hours?

    today = Date.current
    initial_day  = today + INITIAL_LEAD_DAYS
    reminder_day = today + REMINDER_LEAD_DAYS

    @pending = {}

    League.where(attendance_enabled: true).each do |league|
      process_initial_for(league, initial_day)
      process_reminder_for(league, reminder_day)
    end

    dispatch_pending_per_user!
  end

  def quiet_hours?
    hour = Time.now.in_time_zone(LOCAL_TIMEZONE).hour
    hour >= QUIET_HOURS_START || hour < QUIET_HOURS_END
  end

  def self.preview(today: Date.current)
    initial_day  = today + INITIAL_LEAD_DAYS
    reminder_day = today + REMINDER_LEAD_DAYS
    output = []

    League.where(attendance_enabled: true).each do |league|
      output << "League: #{league.name}"
      games_initial  = league.games.where(:game_time.gte => initial_day.beginning_of_day,
                                          :game_time.lte => initial_day.end_of_day)
      games_reminder = league.games.where(:game_time.gte => reminder_day.beginning_of_day,
                                          :game_time.lte => reminder_day.end_of_day)
      teams_initial  = games_initial.flat_map { |g| g.team_ids }.uniq.size
      pending_count  = AttendancePrompt.where(
        :team_id.in => games_reminder.flat_map { |g| g.team_ids },
        game_day: reminder_day, status: 'pending'
      ).count
      output << "  Initial (#{initial_day}): #{games_initial.count} game(s) across #{teams_initial} team(s)"
      output << "  Reminder (#{reminder_day}): #{games_reminder.count} game(s); pending prompts to remind: #{pending_count}"
    end

    output
  end

  private

  def process_initial_for(league, game_day)
    games = league.games.where(:game_time.gte => game_day.beginning_of_day,
                               :game_time.lte => game_day.end_of_day).to_a
    teams_for_day = group_games_by_team(games)
    teams_for_day.each do |team_id, day_games|
      next if all_rained_out?(day_games)
      team = Team.find(team_id)
      team.players.each do |player|
        next if AttendancePrompt.where(user_id: player._id, team_id: team_id, game_day: game_day).exists?
        prompt = AttendancePrompt.create!(
          user: player, team: team, league: league,
          game_day: game_day, game_ids: day_games.map(&:_id),
          status: 'pending'
        )
        queue_for_dispatch(player, prompt, kind: 'initial')
      end
    end
  end

  def process_reminder_for(league, game_day)
    games = league.games.where(:game_time.gte => game_day.beginning_of_day,
                               :game_time.lte => game_day.end_of_day).to_a
    teams_for_day = group_games_by_team(games)
    teams_for_day.each do |team_id, day_games|
      next if all_rained_out?(day_games)
      AttendancePrompt.where(team_id: team_id, game_day: game_day, status: 'pending').each do |prompt|
        already_reminded = AttendancePromptDispatch.where(
          user_id: prompt.user_id, kind: 'reminder',
          'prompts.prompt_id' => prompt._id.to_s
        ).exists?
        next if already_reminded
        queue_for_dispatch(prompt.user, prompt, kind: 'reminder')
      end
    end
  end

  def group_games_by_team(games)
    grouping = {}
    games.each do |g|
      g.team_ids.each do |tid|
        grouping[tid] ||= []
        grouping[tid] << g
      end
    end
    grouping
  end

  def all_rained_out?(games)
    games.all? { |g| g.rained_out? }
  end

  def queue_for_dispatch(user, prompt, kind:)
    @pending[user._id] ||= { user: user, kind: kind, prompts: [] }
    @pending[user._id][:prompts] << prompt
    if @pending[user._id][:kind] == 'reminder' && kind == 'initial'
      @pending[user._id][:kind] = 'initial'
    end
  end

  def dispatch_pending_per_user!
    @pending.each_value do |entry|
      AttendancePromptDispatcher.new(
        user: entry[:user], prompts: entry[:prompts], kind: entry[:kind]
      ).dispatch!
    end
  end
end
