class MailChimpWorker
  include Sidekiq::Worker

  def perform(user_id)
    user= User.find(user_id)
    subscribe_to_mailchimp(ENV['USERS_LIST_ID'], user)
    if user_id.subscribe_newsletter
      subscribe_to_mailchimp(ENV['NEWSLETTER_LIST_ID'], user)
    end
  end

  def subscribe_to_mailchimp(list_id, user)
     gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_API_KEY'])
 
     gibbon.lists(list_id).members(user.email_md5)
     .upsert(body: { email_address: user.email_address,
       status: 'subscribed',
       merge_fields: { FNAME: user.firstname, LNAME: user.lastname }
       })
   end
end
