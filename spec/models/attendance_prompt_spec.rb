require 'spec_helper'

describe AttendancePrompt do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }

  describe "validations" do
    it "is valid with required fields" do
      ap = FactoryGirl.build(:attendance_prompt, user: user, team: team, league: league)
      ap.should be_valid
    end

    it "requires status to be one of pending/yes/no/partial" do
      ap = FactoryGirl.build(:attendance_prompt, user: user, team: team, league: league, status: 'maybe')
      ap.should_not be_valid
    end

    it "auto-generates a web_token if not set" do
      ap = AttendancePrompt.create!(user: user, team: team, league: league, game_day: Date.current + 2, status: 'pending')
      ap.web_token.should_not be_blank
      ap.web_token.length.should be >= 16
    end
  end

  describe "uniqueness" do
    it "rejects a duplicate (user, team, game_day) tuple" do
      day = Date.current + 3
      FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: day)
      dup = FactoryGirl.build(:attendance_prompt, user: user, team: team, league: league, game_day: day)
      dup.should_not be_valid
    end
  end

  describe "scopes" do
    it "active_pending includes today and future pending prompts" do
      future = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 1, status: 'pending')
      AttendancePrompt.active_pending.to_a.should include(future)
    end

    it "active_pending excludes past-game-day prompts even if status is pending" do
      past = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current - 1, status: 'pending')
      AttendancePrompt.active_pending.to_a.should_not include(past)
    end

    it "active_pending excludes resolved prompts even if game_day is future" do
      resolved = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 3, status: 'yes')
      AttendancePrompt.active_pending.to_a.should_not include(resolved)
    end

    it "for_user filters by user" do
      mine  = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league)
      other_user = FactoryGirl.create(:user)
      other = FactoryGirl.create(:attendance_prompt, user: other_user, team: team, league: league, game_day: Date.current + 5)
      AttendancePrompt.for_user(user).to_a.should include(mine)
      AttendancePrompt.for_user(user).to_a.should_not include(other)
    end
  end

  describe "#record_response!" do
    let(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }

    it "sets status, responded_by, response_method, responded_at" do
      prompt.record_response!(status: 'yes', responded_by: user, response_method: 'sms', note: 'lets go')
      prompt.reload
      prompt.status.should eq('yes')
      prompt.responded_by.should eq(user)
      prompt.response_method.should eq('sms')
      prompt.note.should eq('lets go')
      prompt.responded_at.should_not be_nil
    end

    it "rejects invalid statuses" do
      lambda { prompt.record_response!(status: 'banana', responded_by: user, response_method: 'sms') }.should raise_error(ArgumentError)
    end
  end
end
