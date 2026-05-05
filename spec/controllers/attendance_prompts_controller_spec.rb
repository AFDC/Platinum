require 'spec_helper'

describe AttendancePromptsController, type: :controller do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }
  let!(:nm)    { FactoryGirl.create(:notification_method, user: user, target: '4045551111') }
  let(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }

  describe "POST #sms_webhook" do
    before do
      AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial', target: '4045551111',
        prompts: [{ 'prompt_id' => prompt._id.to_s, 'prefix' => 1 }]
      )
    end

    it "applies a YES code from a known phone" do
      post :sms_webhook, From: '+14045551111', Body: '11'
      response.should be_success
      prompt.reload.status.should eq('yes')
    end

    it "responds with TwiML acknowledging unknown numbers" do
      post :sms_webhook, From: '+19999999999', Body: 'YES'
      response.body.should match(%r{<Response>})
      response.body.should match(/recognize/i)
    end

    it "responds with TwiML when no pending prompts" do
      AttendancePromptDispatch.delete_all
      post :sms_webhook, From: '+14045551111', Body: 'YES'
      response.body.should match(/no active attendance/i)
    end
  end

  describe "GET #show" do
    render_views

    it "renders the RSVP page for a valid token" do
      get :show, token: prompt.web_token
      response.should be_success
      assigns(:prompt).should eq(prompt)
    end

    it "404s on an unknown token" do
      get :show, token: 'bogus'
      response.status.should eq(404)
    end

    it "shows a passed-game state for past game-days" do
      prompt.update_attributes!(game_day: Date.current - 1)
      get :show, token: prompt.web_token
      response.body.should match(/has already happened/i)
    end
  end

  describe "PATCH #update" do
    it "records a YES from the web" do
      patch :update, token: prompt.web_token, status: 'yes', note: 'pumped'
      prompt.reload
      prompt.status.should eq('yes')
      prompt.response_method.should eq('web')
      prompt.note.should eq('pumped')
    end

    it "rejects invalid status" do
      patch :update, token: prompt.web_token, status: 'banana'
      response.status.should eq(422)
      prompt.reload.status.should eq('pending')
    end
  end
end
