require 'spec_helper'

describe AttendanceReplyParser do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }

  def make_dispatch(user:, prompts:)
    AttendancePromptDispatch.create!(
      user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
      prompts: prompts.each_with_index.map { |p, i| { 'prompt_id' => p._id.to_s, 'prefix' => i + 1 } }
    )
  end

  describe "single-code single-prompt" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    it "parses '11' as YES" do
      AttendanceReplyParser.parse(user: user, body: "11")
      prompt.reload
      prompt.status.should eq('yes')
      prompt.response_method.should eq('sms')
    end

    it "parses '12' as NO" do
      AttendanceReplyParser.parse(user: user, body: "12")
      prompt.reload.status.should eq('no')
    end

    it "parses '13' as PARTIAL" do
      AttendanceReplyParser.parse(user: user, body: "13")
      prompt.reload.status.should eq('partial')
    end

    it "captures a note after the code" do
      AttendanceReplyParser.parse(user: user, body: "11 LETS GO")
      prompt.reload
      prompt.status.should eq('yes')
      prompt.note.should eq('LETS GO')
    end
  end

  describe "fuzzy YES/NO with single pending" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    %w(yes y yep yeah in coming YES Yes).each do |body|
      it "treats #{body.inspect} as YES" do
        AttendanceReplyParser.parse(user: user, body: body)
        prompt.reload.status.should eq('yes')
      end
    end

    %w(no n nope out cant can't NO).each do |body|
      it "treats #{body.inspect} as NO" do
        AttendanceReplyParser.parse(user: user, body: body)
        prompt.reload.status.should eq('no')
      end
    end
  end

  describe "no anchor dispatch" do
    it "returns a no_pending result without raising" do
      result = AttendanceReplyParser.parse(user: user, body: "11")
      result.kind.should eq(:no_pending)
    end
  end

  describe "freeform without recognizable intent" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    it "captures the full body as a note and leaves status pending" do
      AttendanceReplyParser.parse(user: user, body: "depends on weather")
      prompt.reload
      prompt.status.should eq('pending')
      prompt.note.should eq('depends on weather')
    end

    it "returns kind :note_only" do
      result = AttendanceReplyParser.parse(user: user, body: "??")
      result.kind.should eq(:note_only)
    end
  end

  describe "multi-code multi-prompt" do
    let!(:p1) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 2) }
    let!(:p2) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4) }
    before do
      AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }, { 'prompt_id' => p2._id.to_s, 'prefix' => 2 }]
      )
    end

    it "applies both codes" do
      AttendanceReplyParser.parse(user: user, body: "11 22")
      p1.reload.status.should eq('yes')
      p2.reload.status.should eq('no')
    end

    it "applies notes between codes to their preceding prompt" do
      AttendanceReplyParser.parse(user: user, body: "11 sounds good 22 cant make it")
      p1.reload
      p2.reload
      p1.status.should eq('yes')
      p1.note.should eq('sounds good')
      p2.status.should eq('no')
      p2.note.should eq('cant make it')
    end

    it "ignores codes that don't resolve" do
      AttendanceReplyParser.parse(user: user, body: "11 99")
      p1.reload.status.should eq('yes')
      p2.reload.status.should eq('pending')
    end

    it "ignores codes whose suffix isn't 1/2/3" do
      AttendanceReplyParser.parse(user: user, body: "14")
      p1.reload.status.should eq('pending')
    end
  end

  describe "stale code resolution" do
    it "resolves to the most recent dispatch's mapping when a newer dispatch exists" do
      old_p = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 1)
      new_p = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 5)
      AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 2.days.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => old_p._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => new_p._id.to_s, 'prefix' => 1 }])

      AttendanceReplyParser.parse(user: user, body: "11")
      new_p.reload.status.should eq('yes')
      old_p.reload.status.should eq('pending')
    end
  end
end
