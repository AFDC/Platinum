require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:league_attributes) do
    { name: 'Free league', age_division: 'adult', season: 'spring', sport: 'ultimate',
      self_rank_type: 'simple', price: '0' }
  end

  before do
    session[:user_id] = user.id
    controller.stub(:current_user).and_return(user)
    controller.stub(:log_audit)
    Authorization.stub(:current_user).and_return(user)
    user.stub(:role_symbols).and_return([:'league-manager', :user])
  end

  it 'renders a warning without creating a zero-price league when unconfirmed' do
    expect { post :create, league: league_attributes }.not_to change(League, :count)
    response.should render_template(:new)
    assigns(:league).errors[:confirm_free_registration].should be_present
  end

  it 'creates an explicitly confirmed free league' do
    expect do
      post :create, league: league_attributes.merge(confirm_free_registration: '1')
    end.to change(League, :count).by(1)
    League.last.price.should eq(0)
    response.should redirect_to(league_path(League.last))
  end

  it 'rejects a blank price even with confirmation' do
    expect do
      post :create, league: league_attributes.merge(price: '', confirm_free_registration: '1')
    end.not_to change(League, :count)
    assigns(:league).errors[:price].should be_present
  end

  it 'does not save an unconfirmed change from paid to free' do
    league = FactoryGirl.create(:league)
    put :update, id: league.id, league: { price: '0' }
    response.should render_template(:edit)
    league.reload.price.should eq(50)
  end

  it 'cancels an active free registration without attempting a refund' do
    league = FactoryGirl.create(:league, price: 0, confirm_free_registration: '1', start_date: 1.week.from_now)
    registration = Registration.create!(league: league, user: user, status: 'active',
      waiver_acceptance_date: Time.now, availability: { 'general' => '100%' }, self_rank: 5, player_strength: 'Both', paid: false)
    Braintree::Transaction.should_not_receive(:refund)
    post :cancel_registration, id: league.id, registration_id: registration.id, format: :json
    response.status.should eq(200)
    registration.reload.status.should eq('canceled')
  end
end
