require 'spec_helper'

describe AttendancePromptDispatcher do
  let(:user)    { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league) }
  let(:team)    { FactoryGirl.create(:team, league: league) }
  let!(:sms_nm) { FactoryGirl.create(:notification_method, user: user, method: 'text', target: '4045551111', confirmed: true, enabled: true) }
  let(:p1)      { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4, game_ids: []) }

  before do
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
  end

  describe "channel selection" do
    it "selects SMS when user has confirmed+enabled text method" do
      AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').dispatch!
      AttendancePromptDispatch.where(user_id: user._id).first.channel.should eq('sms')
    end

    it "creates one Dispatch per SMS target" do
      FactoryGirl.create(:notification_method, user: user, method: 'text', target: '4045552222', confirmed: true, enabled: true)
      AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').dispatch!
      AttendancePromptDispatch.where(user_id: user._id).count.should eq(2)
    end

    it "selects email when no SMS target available, using the user's auto-created email NM" do
      sms_nm.update_attributes!(enabled: false)
      mock_mail = double('mail', deliver: true)
      AttendanceMailer.should_receive(:attendance_prompt).and_return(mock_mail)
      AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').dispatch!
      AttendancePromptDispatch.where(user_id: user._id, channel: 'email').count.should eq(1)
    end

    it "skips email when user has email NMs but all disabled (opt-out)" do
      sms_nm.update_attributes!(enabled: false)
      # Disable the auto-created primary email NM
      user.notification_methods.where(method: 'email').each { |nm| nm.update_attributes!(enabled: false) }
      AttendanceMailer.should_not_receive(:attendance_prompt)
      AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').dispatch!
      AttendancePromptDispatch.where(user_id: user._id).count.should eq(0)
    end

    it "falls back to user.email_address when no email NMs exist" do
      sms_nm.destroy
      # Remove the auto-created email NM so we exercise the fallback path
      user.notification_methods.where(method: 'email').delete_all
      mock_mail = double('mail', deliver: true)
      AttendanceMailer.should_receive(:attendance_prompt).and_return(mock_mail)
      AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').dispatch!
      d = AttendancePromptDispatch.where(user_id: user._id, channel: 'email').first
      d.target.should eq(user.email_address)
    end
  end

  describe "SMS body" do
    it "produces the single-game-day template when only one prompt" do
      body = AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').sms_body
      body.should match(/Reply 11 for YES/i)
    end

    it "produces the multi-game-day template when 2+ prompts" do
      p2 = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 6)
      body = AttendancePromptDispatcher.new(user: user, prompts: [p1, p2], kind: 'initial').sms_body
      body.should match(/11 YES/)
      body.should match(/21 YES/)
    end
  end

  describe "Dispatch persistence" do
    it "stores prompt-id/prefix mapping in order" do
      p2 = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 6)
      AttendancePromptDispatcher.new(user: user, prompts: [p1, p2], kind: 'initial').dispatch!
      d = AttendancePromptDispatch.where(user_id: user._id).first
      d.prompts.size.should eq(2)
      d.prompts[0]['prefix'].should eq(1)
      d.prompts[0]['prompt_id'].should eq(p1._id.to_s)
      d.prompts[1]['prefix'].should eq(2)
    end
  end
end
