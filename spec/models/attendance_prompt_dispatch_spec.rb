require 'spec_helper'

describe AttendancePromptDispatch do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }
  let(:p1)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 3) }
  let(:p2)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 5) }

  describe "validations" do
    it "requires channel to be sms or email" do
      d = FactoryGirl.build(:attendance_prompt_dispatch, channel: 'pigeon')
      d.should_not be_valid
    end

    it "requires kind to be initial or reminder" do
      d = FactoryGirl.build(:attendance_prompt_dispatch, kind: 'whenever')
      d.should_not be_valid
    end
  end

  describe "#prompt_for_prefix" do
    it "returns the prompt with the matching prefix" do
      d = AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }, { 'prompt_id' => p2._id.to_s, 'prefix' => 2 }]
      )
      d.prompt_for_prefix(1).should eq(p1)
      d.prompt_for_prefix(2).should eq(p2)
      d.prompt_for_prefix(3).should be_nil
    end
  end

  describe ".latest_active_for_user" do
    it "returns the most recent SMS dispatch with at least one active-pending prompt" do
      old_d = AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 2.days.ago, kind: 'initial',
                                               prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      new_d = AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'reminder',
                                               prompts: [{ 'prompt_id' => p2._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should eq(new_d)
    end

    it "skips dispatches whose prompts are all resolved or past" do
      p1.record_response!(status: 'yes', responded_by: user, response_method: 'sms')
      AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should be_nil
    end

    it "ignores email dispatches" do
      AttendancePromptDispatch.create!(user: user, channel: 'email', sent_at: 1.hour.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should be_nil
    end
  end
end
