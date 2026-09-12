require 'spec_helper'

describe 'Free league registration' do
  describe 'price safeguards' do
    [nil, '', ' ', 'oops', -1, '0.5', 250].each do |price|
      it "rejects an invalid base price: #{price.inspect}" do
        league = FactoryGirl.build(:league, price: price, confirm_free_registration: '1')
        league.valid?.should eq(false)
        league.errors[:price].should be_present
      end
    end

    League::REGISTRATION_PRICE_FIELDS.each do |field|
      it "requires explicit confirmation for zero #{field}" do
        league = FactoryGirl.build(:league, field => 0)
        league.valid?.should eq(false)
        league.errors[:confirm_free_registration].should be_present
        league.confirm_free_registration = '1'
        league.valid?.should eq(true)
      end
    end

    it 'keeps optional blank prices as fallbacks' do
      league = FactoryGirl.build(:league, price_women: '', price_single_day: '', price_women_single_day: '')
      league.valid?.should eq(true)
      league.get_price('female', single_day: true).should eq(50)
    end

    it 'requires confirmation when changing a paid price to zero' do
      league = FactoryGirl.create(:league)
      league.price = 0
      league.save.should eq(false)
      league.confirm_free_registration = '1'
      league.save.should eq(true)
      league = League.find(league.id)
      league.update_attributes(name: 'Renamed free league').should eq(true)
    end

    it 'requires new confirmation when another price is changed to zero' do
      league = FactoryGirl.create(:league, price: 0, confirm_free_registration: '1')
      league = League.find(league.id)
      league.update_attributes(price_women: 0).should eq(false)
    end
  end

  let(:league) do
    FactoryGirl.create(:league, price: 0, confirm_free_registration: '1',
      registration_open: 1.week.ago.to_date, registration_close: 1.week.from_now.to_date,
      male_limit: 1, female_limit: 1)
  end
  let(:user) { FactoryGirl.create(:user) }
  let(:registration) do
    Registration.create!(league: league, user: user, status: 'waitlisted',
      waitlist_timestamp: Time.now, waiver_acceptance_date: Time.now,
      availability: { 'general' => '100%' }, self_rank: 5, player_strength: 'Both', paid: false)
  end

  before do
    RegistrationMailer.stub(:delay).and_return(double('mailer').as_null_object)
  end

  it 'does not treat a missing registration price as free' do
    Registration.new(price: nil).free?.should eq(false)
  end

  it 'uses the stored price, even if the league price changes' do
    registration.free?.should eq(true)
    league.update_attributes!(price: 50)
    registration.reload.free?.should eq(true)
  end

  it 'promotes a free waitlisted player manually without payment details' do
    Braintree::Transaction.should_not_receive(:sale)
    league.add_to_league(registration)
    registration.reload.status.should eq('active')
    registration.paid.should eq(false)
    registration.payment_transactions.count.should eq(0)
  end

  it 'fills an open slot from the free waitlist without payment details' do
    registration
    Braintree::Transaction.should_not_receive(:sale)
    league.fill_slots_from_waitlist.should eq(1)
    registration.reload.status.should eq('active')
  end

  it 'keeps free players waitlisted while capacity is full' do
    registration
    other = FactoryGirl.create(:user)
    Registration.create!(league: league, user: other, status: 'active',
      waiver_acceptance_date: Time.now, availability: { 'general' => '100%' }, self_rank: 5, player_strength: 'Both')
    Braintree::Transaction.should_not_receive(:sale)
    league.fill_slots_from_waitlist.should eq(0)
    registration.reload.status.should eq('waitlisted')
  end

  it 'still requires payment details for paid waitlist promotion' do
    registration.update_attributes!(price: 50)
    league.add_to_league(registration)
    registration.reload.status.should eq('canceled')
  end

  it 'honors a zero-price override on a paid league' do
    league.update_attributes!(price: 50, price_women: 0, confirm_free_registration: '1')
    user.update_attribute(:gender, 'female')
    registration.price.should eq(0)
    registration.free?.should eq(true)
  end

  it 'does not send payment reminders for an unfinished free registration' do
    registration.update_attributes!(status: 'registering')
    RegistrationMailer.should_not_receive(:stale_accepted_registration)
    RegistrationPaymentReminderWorker.new.perform(registration.id.to_s)
  end

  it 'allows an active free player to be added to a team' do
    league.add_to_league(registration)
    team = FactoryGirl.create(:team, league: league)
    league.add_player_to_team(user, team, false)
    league.team_for(user).should eq(team)
  end

  it 'bulk-cancels active free registrations without refunds' do
    require 'rake'
    load Rails.root.join('lib/tasks/league.rake') unless Rake::Task.task_defined?('league:refund')
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    league.add_to_league(registration)
    Braintree::Transaction.should_not_receive(:refund)
    Rake::Task['league:refund'].reenable
    Rake::Task['league:refund'].invoke(league.id.to_s)
    registration.reload.status.should eq('canceled')
  end
end
