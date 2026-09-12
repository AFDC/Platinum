require 'spec_helper'

describe RegistrationsController, type: :controller do
  render_views
  let(:player) { FactoryGirl.create(:user) }
  let(:partner) { FactoryGirl.create(:user, firstname: 'Sam') }
  let(:league) { FactoryGirl.create(:league, start_date: Date.current + 7) }
  let!(:registration) do
    reg = Registration.new(league: league, user: player, pair: partner, status: 'active')
    reg.save!(validate: false)
    reg
  end

  before do
    session[:user_id] = player.id
    controller.stub(:current_user).and_return(player)
  end

  it 'offers a confirmed POST action naming the partner' do
    get :edit, id: registration.id
    document = Nokogiri::HTML(response.body)
    form = document.at_css('#leave-pair-form')
    expect(form['method']).to eq('post')
    expect(form['action']).to eq(leave_pair_league_path(league))
    expect(form['onsubmit']).to include('window.confirm', partner.name)
    expect(form.at_css('input[name="pair_id"]')['value']).to eq(partner.id.to_s)
    expect(document.at_css('button[form="leave-pair-form"]').text).to eq('Leave pair')
    expect(form.ancestors('form')).to be_empty
  end

  it 'explains the cutoff instead of offering the action after the league starts' do
    league.set(start_date: Date.current - 1)
    get :edit, id: registration.id
    expect(response.body).to include('Contact your league commissioner to change your pair.')
    expect(response.body).not_to include('leave-pair-form')
  end

  it 'renders the removal action even if the partner user is missing' do
    partner.destroy
    get :edit, id: registration.id
    expect(response).to be_success
    expect(response.body).to include('Unavailable player', '>Leave pair</button>')
  end
end
