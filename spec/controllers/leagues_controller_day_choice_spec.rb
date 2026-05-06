require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:user)   { FactoryGirl.create(:user, gender: 'male') }
  let(:league) do
    FactoryGirl.create(:league,
      game_days: ['tuesday', 'thursday'],
      start_date: 1.week.from_now.to_date,
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

  describe "GET #choose_days" do
    before do
      Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
                .save(validate: false)
    end

    it "renders the interstitial" do
      get :choose_days, id: league._id
      response.should render_template(:choose_days)
    end

    it "rejects when the league has started" do
      league.set(start_date: 1.week.ago.to_date)
      get :choose_days, id: league._id
      response.should redirect_to(registration_path(league.registration_for(user)))
      flash[:error].should match(/already started/i)
    end

    it "rejects when there is no in-progress registration" do
      league.registrations.destroy_all
      get :choose_days, id: league._id
      response.should redirect_to(league_path(league))
    end
  end

  describe "POST #submit_day_choice (new-registration flow)" do
    before do
      Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
                .save(validate: false)
    end

    def reg
      league.registration_for(user)
    end

    it "persists attending_days and redirects back to register" do
      post :submit_day_choice, id: league._id, attending_days: ['tuesday']
      reg.attending_days.should eq(['tuesday'])
      response.should redirect_to(register_league_path(league))
    end

    it "clears price so ensure_price recomputes for the new type" do
      reg.update_attributes(price: 80)
      post :submit_day_choice, id: league._id, attending_days: ['tuesday']
      league.set(price_single_day: 50)
      reg.price.should be_nil
    end

    it "rejects an empty submission" do
      post :submit_day_choice, id: league._id, attending_days: []
      response.should render_template(:choose_days)
      flash.now[:error].should be_present
    end

    it "rejects days outside league.game_days" do
      post :submit_day_choice, id: league._id, attending_days: ['monday']
      response.should render_template(:choose_days)
      flash.now[:error].should be_present
    end

    it "rejects more than two days" do
      post :submit_day_choice, id: league._id, attending_days: ['tuesday', 'thursday', 'monday']
      response.should render_template(:choose_days)
      flash.now[:error].should be_present
    end
  end

  describe "POST #submit_day_choice (change-later flow)" do
    before do
      Registration.new(league: league, user: user, status: 'active', attending_days: ['tuesday', 'thursday'], price: 80, paid: true)
                .save(validate: false)
    end

    def reg
      league.registration_for(user)
    end

    it "persists the change and redirects to registration#show" do
      post :submit_day_choice, id: league._id, attending_days: ['tuesday']
      reg.attending_days.should eq(['tuesday'])
      response.should redirect_to(registration_path(reg))
    end

    it "does NOT clear price for active registrations" do
      post :submit_day_choice, id: league._id, attending_days: ['tuesday']
      reg.price.should eq(80)
    end

    it "is rejected once the league has started" do
      league.set(start_date: 1.week.ago.to_date)
      post :submit_day_choice, id: league._id, attending_days: ['tuesday']
      response.should redirect_to(registration_path(reg))
      flash[:error].should match(/already started/i)
    end
  end
end
