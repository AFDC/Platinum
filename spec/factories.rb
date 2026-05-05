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

  factory :team do
    name 'Test Team'
    league
  end

  factory :game do
    game_time { Time.now.in_time_zone(LOCAL_TIMEZONE) + 3.days }
    field 'Field 1'
    league
  end

  factory :notification_method do
    method 'text'
    target { '4045551212' }
    confirmed true
    enabled true
    user
  end

  factory :attendance_prompt do
    user
    team
    league
    game_day { Date.current + 3 }
    status 'pending'
    web_token { SecureRandom.hex(16) }
  end

  factory :attendance_prompt_dispatch do
    user
    channel 'sms'
    sent_at { Time.now }
    kind 'initial'
    prompts { [] }
  end
end