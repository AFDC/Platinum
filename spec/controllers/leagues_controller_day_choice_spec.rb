require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:user)   { FactoryGirl.create(:user, gender: 'male') }
  let(:league) do
    FactoryGirl.create(:league,
      game_days: ['tuesday', 'thursday'],
      registration_open: 1.week.ago.to_date,
      registration_close: 1.week.from_now.to_date,
      male_limit: 30, female_limit: 30
    )
  end

  before do
    session[:user_id] = user._id
    controller.stub(:current_user).and_return(user)
    User.any_instance.stub(:valid?).and_return(true)
    User.any_instance.stub(:needs_grank_update_for_league?).and_return(false)
  end

  describe "GET #register on a two-day league" do
    it "redirects to choose_days when there's no existing registration" do
      get :register, id: league._id
      response.should redirect_to(choose_days_league_path(league))
    end

    it "redirects to choose_days when resuming a registering registration with blank attending_days" do
      reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
      reg.save(validate: false)
      get :register, id: league._id
      response.should redirect_to(choose_days_league_path(league))
    end

    it "renders edit when attending_days is already set" do
      reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now, attending_days: ['tuesday'])
      reg.save(validate: false)
      get :register, id: league._id
      response.should render_template('registrations/edit')
    end
  end

  describe "GET #register on a one-day or no-day league" do
    let(:single_day_league) do
      FactoryGirl.create(:league,
        game_days: ['tuesday'],
        registration_open: 1.week.ago.to_date,
        registration_close: 1.week.from_now.to_date,
        male_limit: 30
      )
    end

    it "renders edit (no interstitial)" do
      get :register, id: single_day_league._id
      response.should render_template('registrations/edit')
    end
  end
end
