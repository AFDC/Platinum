require 'spec_helper'

describe User do

	it "should be invalid when missing first or last name" do
		FactoryGirl.build(:user, :firstname => '').should_not be_valid
		FactoryGirl.build(:user, :lastname => '').should_not be_valid
	end

	it "should be invalid when missing a gender" do
		FactoryGirl.build(:user, :gender => '').should_not be_valid
	end

	it "should allow only 'male' or 'female' for gender" do
		FactoryGirl.build(:user, :gender => 'male').should be_valid
		FactoryGirl.build(:user, :gender => 'female').should be_valid
		FactoryGirl.build(:user, :gender => 'elephant').should_not be_valid
	end

	it "should allow only 'left', 'right', or 'both' for handedness" do
		FactoryGirl.build(:user, :handedness => 'left').should be_valid
		FactoryGirl.build(:user, :handedness => 'right').should be_valid
		FactoryGirl.build(:user, :handedness => 'both').should be_valid
		FactoryGirl.build(:user, :handedness => 'neither').should_not be_valid
	end

	it "should be invalid when missing an email address" do
		FactoryGirl.build(:user, :email_address => '').should_not be_valid
	end

	it "should disallow duplicate email addresses" do
		FactoryGirl.create(:user, :email_address => 'john.doe@email.com')
		FactoryGirl.build(:user, :email_address => 'john.doe@email.com').should_not be_valid
	end

	it "should ensure resonable height and weight" do
		FactoryGirl.build(:user, :height => 30).should_not be_valid
		FactoryGirl.build(:user, :height => 72).should be_valid
		FactoryGirl.build(:user, :height => 96).should_not be_valid
		FactoryGirl.build(:user, :height => 'rhino').should_not be_valid


		FactoryGirl.build(:user, :weight => 60).should_not be_valid
		FactoryGirl.build(:user, :weight => 200).should be_valid
		FactoryGirl.build(:user, :weight => 400).should_not be_valid
		FactoryGirl.build(:user, :weight => 'purple').should_not be_valid
	end

	it "should have a valid date string" do
		FactoryGirl.build(:user).birthdate.should be_a String
		FactoryGirl.build(:user, :birthdate => 'orangutang').should_not be_valid
	end

	it "should not allow users under 6 years of age" do
		FactoryGirl.build(:user, :birthdate => 5.years.ago.strftime('%Y-%m-%d')).should_not be_valid
	end

	it "should downcase email addresses before save" do
		user = FactoryGirl.create(:user, :email_address => 'SCREAMIN.JOHN@EMAIL.COM')
		user.email_address.should eq('screamin.john@email.com')
	end
end
