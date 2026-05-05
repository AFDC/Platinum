require 'spec_helper'

describe AttendanceMailer do
  describe "#attendance_prompt" do
    let(:user)   { FactoryGirl.create(:user, firstname: 'Pete') }
    let(:league) { FactoryGirl.create(:league) }
    let(:team)   { FactoryGirl.create(:team, league: league) }
    let(:p1)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4) }
    let(:dispatch) {
      AttendancePromptDispatch.create!(
        user: user, channel: 'email', sent_at: Time.now, kind: 'initial', target: 'pete@example.com',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }]
      )
    }

    it "sets to, subject (with ACTION REQUIRED), and renders the user's first name" do
      mail = AttendanceMailer.attendance_prompt(dispatch._id.to_s)
      mail.to.should eq(['pete@example.com'])
      mail.subject.should match(/AFDC/i)
      mail.subject.should match(/ACTION REQUIRED/i)
      mail.body.encoded.should match(/Pete/)
      mail.body.encoded.should match(p1.game_day.strftime('%-m/%-d'))
    end

    it "includes the tokenized RSVP URL using ActionMailer's configured host" do
      mail = AttendanceMailer.attendance_prompt(dispatch._id.to_s)
      mail.body.encoded.should match(p1.web_token)
      # In test env, default_url_options[:host] is 'www.example.com' (Rails default).
      mail.body.encoded.should match(%r{https?://[^/]+/attendance/#{p1.web_token}})
    end
  end
end
