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
end
