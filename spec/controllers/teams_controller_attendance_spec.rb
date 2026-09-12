require 'spec_helper'
require 'active_support/testing/time_helpers'

describe TeamsController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers
  render_views

  around do |example|
    # The attendance window ends the following Monday, not seven days from now.
    # Keep the relative-date fixtures inside that window regardless of the run date.
    travel_to(LOCAL_TIMEZONE.parse(example.metadata[:today] || '2026-09-07 12:00')) { example.run }
  end

  let(:captain) { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }
  let(:player)  { FactoryGirl.create(:user) }

  before do
    team.captains = [captain._id]
    team.players  = [captain._id, player._id]
    team.save!
    session[:user_id] = captain._id
    controller.stub(:current_user).and_return(captain)
  end

  describe "GET #attendance" do
    ['2026-09-12 12:00', '2026-09-13 12:00'].each do |today|
      it 'includes Monday but excludes Tuesday when viewed on a weekend', today: today do
        monday = Date.new(2026, 9, 14)
        [monday, monday + 1].each do |day|
          game = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
          game[:teams] = [team.id]
          game.save!
        end

        get :attendance, id: team.id

        expect(assigns(:upcoming_days)).to eq([monday])
      end
    end

    it "lists upcoming game-days within this week" do
      g = Game.new(league: league, game_time: Time.now + 2.days)
      g[:teams] = [team._id]
      g.save!
      g2 = Game.new(league: league, game_time: Time.now + 9.days)
      g2[:teams] = [team._id]
      g2.save!
      get :attendance, id: team._id
      response.should be_success
      assigns(:upcoming_days).map(&:to_date).should include((Date.current + 2))
      assigns(:upcoming_days).map(&:to_date).should_not include((Date.current + 9))
    end

    it "provides per-day status counts" do
      day = Date.current + 3
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g[:teams] = [team._id]
      g.save!
      FactoryGirl.create(:attendance_prompt, user: captain, team: team, league: league, game_day: day, status: 'yes')
      FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league, game_day: day, status: 'pending')
      get :attendance, id: team._id
      counts = assigns(:counts_by_day)[day]
      counts[:total][:yes].should eq(1)
      counts[:total][:not_answered].should eq(1)
    end

    it "provides gender-split counts" do
      day = Date.current + 3
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g[:teams] = [team._id]
      g.save!
      male_player   = FactoryGirl.create(:user, gender: 'male')
      female_player = FactoryGirl.create(:user, gender: 'female')
      team.players = [male_player._id, female_player._id]
      team.save!
      FactoryGirl.create(:attendance_prompt, user: male_player,   team: team, league: league, game_day: day, status: 'yes')
      FactoryGirl.create(:attendance_prompt, user: female_player, team: team, league: league, game_day: day, status: 'pending')
      get :attendance, id: team._id
      counts = assigns(:counts_by_day)[day]
      counts[:male][:yes].should eq(1)
      counts[:female][:not_answered].should eq(1)
    end

    it "exposes accepted pickup registrations for the day" do
      day = Date.current + 3
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g[:teams] = [team._id]
      g.save!
      pickup_user = FactoryGirl.create(:user, gender: 'female')
      pc = PickupCandidate.new(user: pickup_user, league: league)
      pc.save(validate: false)
      pr = PickupRegistration.new(user: pickup_user, team: team, league: league,
                                  pickup_candidate: pc,
                                  assigned_date: day, status: 'accepted')
      pr.save(validate: false)
      get :attendance, id: team._id
      assigns(:pickups_by_day)[day].size.should eq(1)
      assigns(:pickups_by_day)[day].first.user.should eq(pickup_user)
    end
  end

  describe "PATCH #attendance_override" do
    let(:prompt) { FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league) }

    it "lets a captain set a player's status with response_method captain_override" do
      patch :attendance_override, id: team._id, prompt_id: prompt._id, status: 'no', note: 'told me in person'
      prompt.reload
      prompt.status.should eq('no')
      prompt.response_method.should eq('captain_override')
      prompt.responded_by.should eq(captain)
      prompt.note.should eq('told me in person')
    end
  end

  describe "GET #bulk_attendance" do
    it "loads players and existing prompts for the requested date" do
      day = Date.current + 3
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g[:teams] = [team._id]
      g.save!
      FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league, game_day: day, status: 'no')
      get :bulk_attendance, id: team._id, game_date: day.strftime('%Y-%m-%d')
      response.should be_success
      assigns(:game_day).should eq(day)
      assigns(:players).map(&:_id).should include(captain._id, player._id)
    end
  end

  describe "PATCH #apply_bulk_attendance" do
    let(:day) { Date.current + 3 }

    before do
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse("#{day} 7pm"))
      g[:teams] = [team._id]
      g.save!
    end

    it "creates or updates prompts from the form payload" do
      patch :apply_bulk_attendance, id: team._id,
            game_date: day.strftime('%Y-%m-%d'),
            attendance: {
              player._id.to_s => { 'status' => 'yes', 'note' => 'in' },
              captain._id.to_s => { 'status' => 'no', 'note' => '' },
            }
      AttendancePrompt.where(user_id: player._id, game_day: day).first.status.should eq('yes')
      AttendancePrompt.where(user_id: captain._id, game_day: day).first.status.should eq('no')
    end

    it "skips entries with status='no_change'" do
      FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league, game_day: day, status: 'pending')
      patch :apply_bulk_attendance, id: team._id,
            game_date: day.strftime('%Y-%m-%d'),
            attendance: { player._id.to_s => { 'status' => 'no_change', 'note' => '' } }
      AttendancePrompt.where(user_id: player._id, game_day: day).first.status.should eq('pending')
    end

    it "records response_method as captain_override" do
      patch :apply_bulk_attendance, id: team._id,
            game_date: day.strftime('%Y-%m-%d'),
            attendance: { player._id.to_s => { 'status' => 'yes', 'note' => '' } }
      prompt = AttendancePrompt.where(user_id: player._id, game_day: day).first
      prompt.response_method.should eq('captain_override')
      prompt.responded_by.should eq(captain)
    end
  end
end
