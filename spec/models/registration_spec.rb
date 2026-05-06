require 'spec_helper'

describe Registration do
  let(:user) { FactoryGirl.create(:user) }

  describe "#attending_days" do
    it "defaults to nil" do
      league = FactoryGirl.create(:league)
      reg = Registration.new(league: league, user: user, status: 'queued')
      reg.attending_days.should be_nil
    end
  end

  describe "#single_day?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "is true when attending_days has one entry" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.single_day?.should eq(true)
    end

    it "is false when attending_days has two entries" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.single_day?.should eq(false)
    end

    it "is false when attending_days is nil" do
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.single_day?.should eq(false)
    end
  end

  describe "#chosen_day" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "returns the only day for single-day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.chosen_day.should eq('tuesday')
    end

    it "returns nil for two-day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.chosen_day.should be_nil
    end
  end

  describe "#registration_type_label" do
    it "is nil when league does not require day choice" do
      league = FactoryGirl.create(:league, game_days: [])
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.registration_type_label.should be_nil
    end

    it "is 'Two-day' when attending both days" do
      league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.registration_type_label.should eq('Two-day')
    end

    it "names the chosen day for single-day" do
      league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.registration_type_label.should eq('Tuesday only')
    end
  end

  describe "#participates_on?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "returns true when attending_days is nil (legacy)" do
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.participates_on?('tuesday').should eq(true)
      reg.participates_on?('friday').should eq(true)
    end

    it "returns true when attending_days is empty" do
      reg = Registration.new(league: league, user: user, attending_days: [])
      reg.participates_on?('tuesday').should eq(true)
    end

    it "returns true when attending_days includes the day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('tuesday').should eq(true)
    end

    it "returns false when attending_days excludes the day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('thursday').should eq(false)
    end

    it "is case-insensitive on the input" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('Tuesday').should eq(true)
    end
  end

  describe "#day_choice_editable?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'], start_date: 2.weeks.from_now.to_date) }

    it "is true before the league starts" do
      reg = Registration.new(league: league, user: user)
      reg.day_choice_editable?.should eq(true)
    end

    it "is false once the league has started" do
      league.update_attributes!(start_date: 1.week.ago.to_date)
      reg = Registration.new(league: league, user: user)
      reg.day_choice_editable?.should eq(false)
    end
  end
end
