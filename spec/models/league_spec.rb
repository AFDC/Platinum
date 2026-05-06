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
end
