FactoryGirl.define do
  factory :user do
    firstname 'John'
    lastname  'Doe'
    birthdate '1980-01-01'
    sequence(:email_address) {|n| "johndoe#{n}@email.net"}
    gender 'male'

    password 'pw'
    password_confirmation 'pw'
  end
end