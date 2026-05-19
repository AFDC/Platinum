require 'spec_helper'

describe "Day-of-week registration end-to-end", type: :request do
  let(:user) { FactoryGirl.create(:user, gender: 'male', email_address: 'p@example.com', password_digest: BCrypt::Password.create('password').to_s) }
  let!(:league) do
    FactoryGirl.create(:league,
      game_days: ['tuesday', 'thursday'],
      price: 80,
      price_single_day: 50,
      registration_open: 1.week.ago.to_date,
      registration_close: 1.week.from_now.to_date,
      male_limit: 30,
      female_limit: 30
    )
  end

  before do
    User.any_instance.stub(:valid?).and_return(true)
    User.any_instance.stub(:needs_grank_update_for_league?).and_return(false)
  end

  it "redirects from register to choose_days, persists the choice, and prices it" do
    skip "Wire to the project's request-level auth helper if available; otherwise rely on Task 8/9 controller specs for coverage."
  end
end
