require 'spec_helper'

describe PaymentsController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league, price: 0, confirm_free_registration: '1') }
  let(:registration) do
    reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
    reg.save!(validate: false)
    reg
  end

  before do
    session[:user_id] = user.id
    controller.stub(:current_user).and_return(user)
    Braintree::Transaction.should_not_receive(:sale)
  end

  [:create, :pre_authorize].each do |action|
    it "bypasses the gateway without activating on direct #{action} requests" do
      post action, registration_id: registration.id
      response.should redirect_to(registration_path(registration))
      registration.reload.status.should eq('registering')
      registration.waiver_signature.should be_nil
    end
  end
end
