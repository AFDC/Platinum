require 'spec_helper'

describe AttendancePromptWorker do
  let(:user1)   { FactoryGirl.create(:user) }
  let(:user2)   { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }

  before do
    team.players = [user1._id, user2._id]
    team.save!
    FactoryGirl.create(:notification_method, user: user1, target: '4045551111')
    FactoryGirl.create(:notification_method, user: user2, target: '4045552222')
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
    # Pretend we're outside quiet hours for the existing behavior tests.
    AttendancePromptWorker.any_instance.stub(:quiet_hours?).and_return(false)
  end

  def make_game(game_day, time = '7:00pm', league_arg = league)
    g = Game.new(league: league_arg, game_time: LOCAL_TIMEZONE.parse("#{game_day} #{time}"))
    g[:teams] = [team._id]
    g.save!
    g
  end

  describe "initial window (4 days out)" do
    it "creates AttendancePrompt records for each team player" do
      future_day = (Date.current + 4)
      make_game(future_day)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id, game_day: future_day).count.should eq(2)
    end

    it "does nothing for game-days outside the window" do
      make_game(Date.current + 6)
      AttendancePromptWorker.new.perform
      AttendancePrompt.count.should eq(0)
    end

    it "skips leagues without attendance_enabled" do
      league.update_attributes!(attendance_enabled: false)
      make_game(Date.current + 4)
      AttendancePromptWorker.new.perform
      AttendancePrompt.count.should eq(0)
    end

    it "is idempotent across runs" do
      make_game(Date.current + 4)
      AttendancePromptWorker.new.perform
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id).count.should eq(2)
    end
  end

  describe "reminder window (2 days out)" do
    it "creates a reminder dispatch for users who haven't responded" do
      day = Date.current + 2
      make_game(day)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: day, status: 'pending')
      FactoryGirl.create(:attendance_prompt, user: user2, team: team, league: league, game_day: day, status: 'yes', responded_at: 1.day.ago)
      AttendancePromptWorker.new.perform
      AttendancePromptDispatch.where(user_id: user1._id, kind: 'reminder').count.should eq(1)
      AttendancePromptDispatch.where(user_id: user2._id, kind: 'reminder').count.should eq(0)
    end

    it "is idempotent — does not double-send reminders" do
      day = Date.current + 2
      make_game(day)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: day, status: 'pending')
      AttendancePromptWorker.new.perform
      AttendancePromptWorker.new.perform
      AttendancePromptDispatch.where(user_id: user1._id, kind: 'reminder').count.should eq(1)
    end
  end

  describe "rainout filtering" do
    it "skips game-days where every game is rained out" do
      day = Date.current + 4
      g = make_game(day)
      g.scores = { 'rainout' => true, 'reporter_id' => user1._id }
      g.save!
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id, game_day: day).count.should eq(0)
    end
  end

  describe "batching" do
    it "creates one Dispatch per user covering both same-day prompts" do
      tue = Date.current + 2
      thu = Date.current + 4
      make_game(tue)
      make_game(thu)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: tue, status: 'pending')
      AttendancePromptWorker.new.perform
      ds = AttendancePromptDispatch.where(user_id: user1._id)
      ds.count.should eq(1)
      ds.first.prompts.size.should eq(2)
    end
  end

  describe ".preview" do
    it "returns a list of strings describing what would happen" do
      make_game(Date.current + 4)
      output = AttendancePromptWorker.preview
      output.should be_a(Array)
      output.any? { |line| line.include?('Initial') }.should eq(true)
    end
  end

  describe "day-of-week filtering" do
    let(:two_day_league) do
      FactoryGirl.create(:league,
        attendance_enabled: true,
        game_days: ['tuesday', 'thursday']
      )
    end
    let(:two_day_team) { FactoryGirl.create(:team, league: two_day_league) }
    let(:tuesday_only_player) { FactoryGirl.create(:user) }
    let(:both_days_player)   { FactoryGirl.create(:user) }

    before do
      two_day_team.players = [tuesday_only_player._id, both_days_player._id]
      two_day_team.save!
      Registration.new(league: two_day_league, user: tuesday_only_player, status: 'active', attending_days: ['tuesday']).save(validate: false)
      Registration.new(league: two_day_league, user: both_days_player, status: 'active', attending_days: ['tuesday', 'thursday']).save(validate: false)
      [tuesday_only_player, both_days_player].each do |u|
        FactoryGirl.create(:notification_method, user: u)
      end
    end

    def make_game_in_two_day_league(game_day, time = '7:00pm')
      g = Game.new(league: two_day_league, game_time: LOCAL_TIMEZONE.parse("#{game_day} #{time}"))
      g[:teams] = [two_day_team._id]
      g.save!
      g
    end

    def next_thursday_at_least(days_out)
      d = Date.current + days_out
      d += 1 while d.strftime('%A').downcase != 'thursday'
      d
    end

    def next_tuesday_at_least(days_out)
      d = Date.current + days_out
      d += 1 while d.strftime('%A').downcase != 'tuesday'
      d
    end

    it "creates a prompt for both-days player on a Thursday game" do
      actual_day = next_thursday_at_least(AttendancePromptWorker::INITIAL_LEAD_DAYS)
      make_game_in_two_day_league(actual_day)
      Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: both_days_player._id).count.should eq(1)
    end

    it "does NOT create a prompt for tuesday-only player on a Thursday game" do
      actual_day = next_thursday_at_least(AttendancePromptWorker::INITIAL_LEAD_DAYS)
      make_game_in_two_day_league(actual_day)
      Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: tuesday_only_player._id).count.should eq(0)
    end

    it "creates a prompt for tuesday-only player on a Tuesday game" do
      actual_day = next_tuesday_at_least(AttendancePromptWorker::INITIAL_LEAD_DAYS)
      make_game_in_two_day_league(actual_day)
      Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: tuesday_only_player._id).count.should eq(1)
    end

    it "still creates prompts for legacy players (attending_days nil)" do
      legacy_player = FactoryGirl.create(:user)
      two_day_team.players = two_day_team.players + [legacy_player._id]
      two_day_team.save!
      Registration.new(league: two_day_league, user: legacy_player, status: 'active', attending_days: nil).save(validate: false)
      FactoryGirl.create(:notification_method, user: legacy_player)
      actual_day = next_tuesday_at_least(AttendancePromptWorker::INITIAL_LEAD_DAYS)
      make_game_in_two_day_league(actual_day)
      Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: legacy_player._id).count.should eq(1)
    end
  end

  describe "quiet hours" do
    before { AttendancePromptWorker.any_instance.unstub(:quiet_hours?) }

    it "creates and dispatches no prompts during quiet hours" do
      AttendancePromptWorker.any_instance.stub(:quiet_hours?).and_return(true)
      future_day = Date.current + 4
      make_game(future_day)
      AttendancePromptWorker.new.perform
      AttendancePrompt.count.should eq(0)
      AttendancePromptDispatch.count.should eq(0)
    end

    # Pre-compute the times before stubbing Time.now (the stub installation
    # itself precedes argument evaluation, and Date.current relies on Time.now).
    {
      "9pm Eastern as quiet"        => ['21:00', true],
      "8:59pm Eastern as not quiet" => ['20:59', false],
      "9am Eastern as not quiet"    => ['09:00', false],
      "8:59am Eastern as quiet"     => ['08:59', true],
      "midnight Eastern as quiet"   => ['00:00', true],
    }.each do |label, (clock, expected)|
      it "treats #{label}" do
        target = LOCAL_TIMEZONE.parse("#{Date.current} #{clock}")
        Time.stub(:now).and_return(target)
        AttendancePromptWorker.new.send(:quiet_hours?).should eq(expected)
      end
    end
  end
end
