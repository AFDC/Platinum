class MailChimpWorker
  include Sidekiq::Worker
  include Mailchimp

  def perform(user_id)
    user= User.find(user_id)
    subscribe_to_mailchimp(ENV['USERS_LIST_ID'], user)
    if User.subscribe_newsletter
      subscribe_to_mailchimp(ENV['NEWSLETTER_LIST_ID'], user)
    end
  end
end
