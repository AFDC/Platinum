require 'spec_helper'
require 'active_support/testing/time_helpers'

describe LeaguesController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    # Keep relative-date fixtures inside the current attendance window.
    travel_to(LOCAL_TIMEZONE.parse(example.metadata[:today] || '2026-09-07 12:00')) { example.run }
  end

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
    ['2026-09-12 12:00', '2026-09-13 12:00'].each do |today|
      it 'includes Monday but excludes Tuesday when viewed on a weekend', today: today do
        monday = Date.new(2026, 9, 14)
        [[monday, team_a], [monday + 1, team_b]].each do |day, team|
          game = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
          game[:teams] = [team.id]
          game.save!
        end

        get :attendance_overview, id: league.id

        expect(assigns(:game_days)).to eq([monday])
        expect(assigns(:rows).map { |row| row[:team] }).to eq([team_a])
      end
    end

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
