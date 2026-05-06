require 'spec_helper'

describe League do
  it "defaults attendance_enabled to false" do
    league = FactoryGirl.create(:league)
    league.attendance_enabled.should eq(false)
  end

  it "persists attendance_enabled when set" do
    league = FactoryGirl.create(:league, attendance_enabled: true)
    League.find(league._id).attendance_enabled.should eq(true)
  end

  describe "#game_days" do
    it "defaults to an empty array" do
      league = FactoryGirl.create(:league)
      league.game_days.should eq([])
    end

    it "accepts up to two valid day names" do
      league = FactoryGirl.build(:league, game_days: ['tuesday', 'thursday'])
      league.valid?.should eq(true)
    end

    it "rejects more than two days" do
      league = FactoryGirl.build(:league, game_days: ['monday', 'wednesday', 'friday'])
      league.valid?.should eq(false)
      league.errors[:game_days].should be_present
    end

    it "rejects unknown day names" do
      league = FactoryGirl.build(:league, game_days: ['funday'])
      league.valid?.should eq(false)
      league.errors[:game_days].should be_present
    end

    it "rejects duplicate days" do
      league = FactoryGirl.build(:league, game_days: ['monday', 'monday'])
      league.valid?.should eq(false)
      league.errors[:game_days].should be_present
    end

    it "stores days in canonical Mon->Sun order regardless of input order" do
      league = FactoryGirl.create(:league, game_days: ['thursday', 'tuesday'])
      league.reload.game_days.should eq(['tuesday', 'thursday'])
    end
  end

  describe "#requires_day_choice?" do
    it "is false when game_days is empty" do
      league = FactoryGirl.create(:league, game_days: [])
      league.requires_day_choice?.should eq(false)
    end

    it "is false when game_days has one entry" do
      league = FactoryGirl.create(:league, game_days: ['tuesday'])
      league.requires_day_choice?.should eq(false)
    end

    it "is true when game_days has two entries" do
      league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
      league.requires_day_choice?.should eq(true)
    end
  end

  describe "#get_price" do
    it "returns price for two-day registrations" do
      league = FactoryGirl.create(:league, price: 80, price_single_day: 50)
      league.get_price('male', single_day: false).should eq(80)
    end

    it "returns price_single_day when single_day: true" do
      league = FactoryGirl.create(:league, price: 80, price_single_day: 50)
      league.get_price('male', single_day: true).should eq(50)
    end

    it "falls back to price when price_single_day is blank and single_day: true" do
      league = FactoryGirl.create(:league, price: 80, price_single_day: nil)
      league.get_price('male', single_day: true).should eq(80)
    end

    it "uses price_women for female two-day when set" do
      league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: 35)
      league.get_price('female', single_day: false).should eq(60)
    end

    it "uses price_women_single_day for female single-day when set" do
      league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: 35)
      league.get_price('female', single_day: true).should eq(35)
    end

    it "falls back to price_women when price_women_single_day is blank for female single-day" do
      league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: nil)
      league.get_price('female', single_day: true).should eq(60)
    end

    it "remains backward compatible with one-arg call" do
      league = FactoryGirl.create(:league, price: 80)
      league.get_price('male').should eq(80)
    end

    it "falls back to price_single_day when both women single-day and price_women are blank" do
      league = FactoryGirl.create(:league, price: 80, price_women: nil, price_single_day: 50, price_women_single_day: nil)
      league.get_price('female', single_day: true).should eq(50)
    end
  end
end
