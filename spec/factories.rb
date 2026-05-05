FactoryGirl.define do
  sequence :email do |n|
    "johndoe#{n}@email.net"
  end

  factory :user do
    firstname 'John'
    lastname  'Doe'
    birthdate '1980-01-01'
    email_address { generate(:email) }
    gender 'male'

    password_digest "xxx"
  end

  factory :league do
    name 'Test League'
    age_division 'adult'
    season 'spring'
    sport 'ultimate'
    start_date Date.today
    end_date Date.today + 60
    price 50
    self_rank_type 'simple'
  end
end