class MailChimpWorker
  include Sidekiq::Worker
  include Mailchimp

  def perform(user_id)
    user= User.find(@user.id)
    subscribe_to_mailchimp(ENV['USERS_LIST_ID'], user)
    if subscribe_newsletter
      subscribe_to_mailchimp(ENV['NEWSLETTER_LIST_ID'], user)
    end
  end
end
