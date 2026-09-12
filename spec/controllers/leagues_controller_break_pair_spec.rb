require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:commissioner) { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league, commissioners: [commissioner]) }
  let(:first_player) { FactoryGirl.create(:user, firstname: 'Alex') }
  let(:second_player) { FactoryGirl.create(:user, firstname: 'Sam') }
  let!(:first_registration) { registration_for(first_player, second_player) }
  let!(:second_registration) { registration_for(second_player, first_player) }

  def registration_for(player, partner)
    reg = Registration.new(league: league, user: player, pair: partner, status: 'active')
    # Pair administration must also work for older, incomplete registrations.
    reg.save!(validate: false)
    reg
  end

  def break_pair(overrides = {})
    post :break_pair, { id: league.id, registration_id: first_registration.id,
      pair_id: second_player.id.to_s, format: :json }.merge(overrides)
  end

  before do
    session[:user_id] = commissioner.id
    controller.stub(:current_user).and_return(commissioner)
  end

  it 'allows the league commissioner to break both links and records an audit entry' do
    break_pair
    expect(response.status).to eq(200)
    expect(first_registration.reload.pair_id).to be_nil
    expect(second_registration.reload.pair_id).to be_nil
    log = AuditLog.where(action: 'BreakPair').first
    expect(log.acting_user).to eq(commissioner)
    expect(log.league).to eq(league)
    expect(log.details['user_ids']).to eq([first_player.id.to_s, second_player.id.to_s])
    expect(log.details['registration_ids']).to eq([first_registration.id.to_s, second_registration.id.to_s])
    expect(PairingCoordinator.new(league).excluded_players).not_to include(first_player.id.to_s, second_player.id.to_s)
  end

  it 'keeps registrations, team assignments, and other leagues unchanged' do
    team = FactoryGirl.create(:team, league: league)
    league.add_player_to_team(first_player, team, false)
    league.add_player_to_team(second_player, team, false)
    other_league = FactoryGirl.create(:league)
    other_reg = Registration.new(league: other_league, user: first_player, pair: second_player)
    other_reg.save!(validate: false)
    break_pair
    expect(first_registration.reload.status).to eq('active')
    expect(second_registration.reload.status).to eq('active')
    expect(league.team_for(first_player)).to eq(team)
    expect(league.team_for(second_player)).to eq(team)
    expect(other_reg.reload.pair_id).to eq(second_player.id)
  end

  it 'allows a league manager' do
    commissioner.set(permission_groups: ['user', 'league-manager'])
    league.set(commissioner_ids: [])
    break_pair
    expect(response.status).to eq(200)
  end

  it 'rejects an ordinary player even when they are a member of the pair' do
    controller.stub(:current_user).and_return(first_player)
    session[:user_id] = first_player.id
    break_pair
    expect(response.status).to eq(403)
    expect(first_registration.reload.pair_id).to eq(second_player.id)
    expect(AuditLog.where(action: 'BreakPair').count).to eq(0)
  end

  it 'rejects a commissioner of another league' do
    league.set(commissioner_ids: [])
    FactoryGirl.create(:league, commissioners: [commissioner])
    break_pair
    expect(response.status).to eq(403)
  end

  it 'rejects a registration from another league' do
    other = Registration.new(league: FactoryGirl.create(:league), user: first_player, pair: second_player)
    other.save!(validate: false)
    break_pair(registration_id: other.id)
    expect(response.status).to eq(404)
    expect(other.reload.pair_id).to eq(second_player.id)
  end

  it 'rejects a stale partner selection' do
    break_pair(pair_id: first_player.id.to_s)
    expect(response.status).to eq(409)
    expect(first_registration.reload.pair_id).to eq(second_player.id)
    expect(second_registration.reload.pair_id).to eq(first_player.id)
  end

  it 'rejects a request without the expected partner' do
    break_pair(pair_id: nil)
    expect(response.status).to eq(409)
  end

  it 'does not disturb a partner who has a different pair' do
    third_player = FactoryGirl.create(:user)
    second_registration.set(pair_id: third_player.id)
    break_pair
    expect(response.status).to eq(409)
    expect(second_registration.reload.pair_id).to eq(third_player.id)
  end

  it 'can clear a link to a player whose registration is missing' do
    second_registration.destroy
    break_pair
    expect(response.status).to eq(200)
    expect(first_registration.reload.pair_id).to be_nil
  end

  it 'can break a pair containing a waitlisted registration' do
    second_registration.set(status: 'waitlisted')
    break_pair
    expect(response.status).to eq(200)
    expect(second_registration.reload.pair_id).to be_nil
    expect(second_registration.status).to eq('waitlisted')
  end

  it 'does not duplicate the audit on repeated requests' do
    2.times { break_pair }
    expect(response.status).to eq(409)
    expect(AuditLog.where(action: 'BreakPair').count).to eq(1)
  end

  it 'includes pair information for an individual whose partner is waitlisted' do
    second_registration.set(status: 'waitlisted')
    get :reg_list, id: league.id, format: :json
    row = JSON.parse(response.body).find { |item| item['id'] == first_registration.id.to_s }
    expect(row['type']).to eq('individual')
    expect(row['pair_id']).to eq(second_player.id.to_s)
    expect(row['pair_name']).to eq(second_player.name)
  end
end
