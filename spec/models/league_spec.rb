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
end
