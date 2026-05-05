require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:commish) { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team_a)  { FactoryGirl.create(:team, league: league, name: 'Sharks') }
  let(:team_b)  { FactoryGirl.create(:team, league: league, name: 'Wolves') }

  before do
    league.commissioners << commish
    league.save!
    session[:user_id] = commish._id
    controller.stub(:current_user).and_return(commish)
  end

  describe "GET #attendance_overview" do
    it "shows a row per team for each upcoming game-day" do
      day = Date.current + 3
      g1 = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g1[:teams] = [team_a._id]
      g1.save!
      g2 = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g2[:teams] = [team_b._id]
      g2.save!
      get :attendance_overview, id: league._id
      response.should be_success
      assigns(:rows).size.should eq(2)
    end
  end
end
