class MailChimpWorker
  include Sidekiq::Worker

  def perform(user_id, subscribe)
    user   = User.find(user_id)
    gibbon = Gibbon::Request.new

    subscribe_body = {
      email_address: user.email_address,
      merge_fields: { 
        FNAME: user.firstname,
        LNAME: user.lastname
      }
    }

    if subscribe
      # We want to (re)subscribe the user regardless of their current status if they check the box
      subscribe_body['status'] = 'subscribed'
    else
      # We want to make sure they're in our MailChimp list, but we don't want to unsub them if they're already subscribed
      subscribe_body['status_if_new'] = 'unsubscribed'
    end

    gibbon.lists(list_id).members(user.email_md5).upsert(body: subscribe_body)
  end

  def list_id
    ENV['mailchimp_list_id']
  end
end
