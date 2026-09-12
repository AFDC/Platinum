require 'spec_helper'
require 'active_support/testing/time_helpers'

describe LeaguesController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(LOCAL_TIMEZONE.parse('2026-09-07 12:00')) { example.run }
  end

  let(:league) { FactoryGirl.create(:league, start_date: Date.current + 1) }
  let(:player) { FactoryGirl.create(:user) }
  let(:partner) { FactoryGirl.create(:user) }
  let!(:registration) { create_registration(player, partner) }
  let!(:partner_registration) { create_registration(partner, player) }

  def create_registration(user, pair)
    reg = Registration.new(league: league, user: user, pair: pair, status: 'active')
    reg.save!(validate: false)
    reg
  end

  def leave_pair(extra = {})
    post :leave_pair, { id: league.id, pair_id: partner.id.to_s }.merge(extra)
  end

  before do
    session[:user_id] = player.id
    controller.stub(:current_user).and_return(player)
  end

  it 'clears both links despite incomplete registration data and records the player in the audit' do
    expect(registration.valid?).to eq(false)
    leave_pair
    expect(response).to redirect_to(edit_registration_path(registration))
    expect(registration.reload.pair_id).to be_nil
    expect(partner_registration.reload.pair_id).to be_nil
    expect(PairingCoordinator.new(league).excluded_players).not_to include(player.id.to_s, partner.id.to_s)
    log = AuditLog.where(action: 'LeavePair').first
    expect(log.acting_user).to eq(player)
    expect(log.details['user_ids']).to eq([player.id.to_s, partner.id.to_s])
  end

  it 'preserves team assignments and registration status' do
    team = FactoryGirl.create(:team, league: league)
    [player, partner].each { |user| league.add_player_to_team(user, team, false) }
    leave_pair
    expect(league.team_for(player)).to eq(team)
    expect(league.team_for(partner)).to eq(team)
    expect(registration.reload.status).to eq('active')
    expect(partner_registration.reload.status).to eq('active')
  end

  it 'refuses removal on the league start date' do
    league.set(start_date: Date.current)
    leave_pair
    expect(flash[:error]).to match(/league has started/)
    expect(registration.reload.pair_id).to eq(partner.id)
    expect(AuditLog.where(action: 'LeavePair').count).to eq(0)
  end

  it 'requires login' do
    session.delete(:user_id)
    controller.stub(:current_user).and_return(nil)
    leave_pair
    expect(response).to redirect_to(auth_path)
    expect(registration.reload.pair_id).to eq(partner.id)
  end

  it 'does not let an unregistered player target another registration' do
    outsider = FactoryGirl.create(:user)
    session[:user_id] = outsider.id
    controller.stub(:current_user).and_return(outsider)
    leave_pair(registration_id: registration.id)
    expect(response).to redirect_to(league_path(league))
    expect(flash[:error]).to match(/do not have a registration/)
    expect(registration.reload.pair_id).to eq(partner.id)
  end

  it 'uses the logged-in player even if another registration ID is supplied' do
    other = create_registration(FactoryGirl.create(:user), partner)
    leave_pair(registration_id: other.id)
    expect(other.reload.pair_id).to eq(partner.id)
    expect(registration.reload.pair_id).to be_nil
  end

  it 'redirects old GET links without changing the pair' do
    get :leave_pair, id: league.id
    expect(response).to redirect_to(edit_registration_path(registration))
    expect(registration.reload.pair_id).to eq(partner.id)
  end

  it 'rejects a stale or missing partner confirmation' do
    [player.id.to_s, nil].each do |pair_id|
      leave_pair(pair_id: pair_id)
      expect(flash[:error]).to match(/pair has changed/)
      expect(registration.reload.pair_id).to eq(partner.id)
    end
  end

  it 'handles a missing partner registration' do
    partner_registration.destroy
    leave_pair
    expect(registration.reload.pair_id).to be_nil
  end

  it 'repairs a one-sided link left by a previously failed removal' do
    partner_registration.set(pair_id: nil)
    leave_pair
    expect(registration.reload.pair_id).to be_nil
    expect(PairingCoordinator.new(league).excluded_players).not_to include(player.id.to_s, partner.id.to_s)
  end

  it 'does not clear a partner who is now paired with someone else' do
    other_player = FactoryGirl.create(:user)
    partner_registration.set(pair_id: other_player.id)
    leave_pair
    expect(flash[:error]).to match(/pair has changed/)
    expect(partner_registration.reload.pair_id).to eq(other_player.id)
  end

  it 'handles a repeated submission without another audit entry' do
    2.times { leave_pair }
    expect(flash[:notice]).to eq('You are no longer paired.')
    expect(AuditLog.where(action: 'LeavePair').count).to eq(1)
  end
end
