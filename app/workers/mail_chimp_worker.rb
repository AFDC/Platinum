class MailChimpWorker
  include Sidekiq::Worker

  def perform(user_id, subscribe)
    user = User.find(user_id)
    subscribe_to_mailchimp(ENV['mailchimp_list_id'], user, subscribe)
  end

  def subscribe_to_mailchimp(list_id, user, subscribe)
    gibbon = Gibbon::Request.new(api_key: ENV['mailchimp_api_key'])

    status = 'subscribed'
    status = 'unsubscribed' unless subscribe

    gibbon.lists(list_id).members(user.email_md5).upsert(body: {
      email_address: user.email_address,
      status: status,
      merge_fields: { 
        FNAME: user.firstname,
        LNAME: user.lastname
      }
     })
  end
end
