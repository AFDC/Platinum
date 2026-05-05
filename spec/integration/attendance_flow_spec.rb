require 'spec_helper'

describe "Attendance end-to-end" do
  let(:captain) { FactoryGirl.create(:user) }
  let(:player)  { FactoryGirl.create(:user, firstname: 'Pete') }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }

  before do
    team.captains = [captain._id]
    team.players  = [captain._id, player._id]
    team.save!
    FactoryGirl.create(:notification_method, user: captain, target: '4045551111')
    FactoryGirl.create(:notification_method, user: player,  target: '4045552222')
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
  end

  it "creates prompts on the worker run, applies an SMS reply, and persists status" do
    day = Date.current + 4
    g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
    g[:teams] = [team._id]
    g.save!

    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: team._id, game_day: day).count.should eq(2)
    AttendancePromptDispatch.where(user_id: player._id).count.should eq(1)

    AttendanceReplyParser.parse(user: player, body: "11")
    pl_prompt = AttendancePrompt.where(user_id: player._id, game_day: day).first
    pl_prompt.status.should eq('yes')
    pl_prompt.response_method.should eq('sms')
  end
end
