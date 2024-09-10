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
end