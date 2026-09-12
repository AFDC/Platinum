require 'spec_helper'

describe RegistrationsController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:league) do
    FactoryGirl.create(:league, price: 0, confirm_free_registration: '1',
      solicit_donations: true, allow_pairs: false,
      registration_open: 1.week.ago.to_date, registration_close: 1.week.from_now.to_date,
      male_limit: 30, female_limit: 30)
  end
  let!(:registration) do
    reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
    reg.save!(validate: false)
    reg
  end
  let(:form_params) { { waiver_accepted: '1', gen_availability: '100%', self_rank: '5', player_strength: 'Both' } }

  before do
    session[:user_id] = user.id
    controller.stub(:current_user).and_return(user)
    controller.stub(:log_audit)
    MailChimpWorker.stub(:perform_async)
    RegistrationMailer.stub(:delay).and_return(double('mailer').as_null_object)
    Waiver.create!(url: 'https://example.com/waiver', league_default: true)
    Braintree::Transaction.should_not_receive(:sale)
  end

  it 'records the waiver and activates without checkout or donations' do
    put :update, id: registration.id, registration: form_params
    response.should redirect_to(registration_path(registration))
    registration.reload.status.should eq('active')
    registration.waiver_signature.should be_present
    registration.waiver_signature.identity_verification_timestamp.should eq(registration.waiver_acceptance_date)
    registration.paid.should eq(false)
    registration.comped.should_not eq(true)
    registration.expires_at.should be_nil
    registration.payment_transactions.count.should eq(0)
  end

  it 'requires waiver acceptance' do
    put :update, id: registration.id, registration: form_params.merge(waiver_accepted: '0')
    response.should render_template(:edit)
    registration.reload.status.should eq('registering')
    registration.waiver_signature.should be_nil
  end

  it 'does not activate if the waiver signature could not be recorded' do
    WaiverSignature.stub(:create_from_registration!).and_return(nil)
    Bugsnag.stub(:notify)
    put :update, id: registration.id, registration: form_params
    response.should render_template(:edit)
    registration.reload.status.should eq('registering')
  end

  it 'joins the waitlist without authorization and records the waiver' do
    registration.update_attribute(:status, 'registering_waitlisted')
    put :update, id: registration.id, registration: form_params
    registration.reload.status.should eq('waitlisted')
    registration.pre_authorization.should be_nil
    registration.waiver_signature.should be_present
    registration.expires_at.should be_nil
  end

  it 'does not complete expired registrations' do
    registration.set(expires_at: 1.minute.ago)
    put :update, id: registration.id, registration: form_params
    response.should redirect_to(register_league_path(league))
    registration.reload.status.should eq('registering')
  end

  it 'does not complete registrations after registration closes' do
    league.set(registration_close: 1.day.ago.to_date)
    put :update, id: registration.id, registration: form_params
    response.should redirect_to(league_path(league))
    registration.reload.status.should eq('registering')
  end

  it 'sends paid registrations through the existing donation flow' do
    registration.set(price: 50)
    put :update, id: registration.id, registration: form_params
    response.should redirect_to(donate_registration_path(registration))
    registration.reload.status.should eq('registering')
  end

  it 'sends paid registrations to checkout when donations are disabled' do
    registration.set(price: 50)
    league.set(solicit_donations: false)
    put :update, id: registration.id, registration: form_params
    response.should redirect_to(pay_registration_path(registration))
  end

  it 'redirects a direct free checkout visit to the registration form' do
    get :pay, id: registration.id
    response.should redirect_to(edit_registration_path(registration))
    registration.reload.status.should eq('registering')
  end

  it 'does not send duplicate activation emails when a form is submitted twice' do
    mailer = double('mailer')
    RegistrationMailer.stub(:delay).and_return(mailer)
    mailer.should_receive(:registration_active).with(registration.id.to_s).once
    2.times { put :update, id: registration.id, registration: form_params }
    registration.reload.status.should eq('active')
    WaiverSignature.where(registration: registration).count.should eq(1)
  end
end
