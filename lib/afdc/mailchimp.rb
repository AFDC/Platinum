module Mailchimp
  def subscribe_to_mailchimp(list_id, user)
    gibbon = Gibbon::Request.new(api_key: ENV['MAILCHIMP_API_KEY'])

    gibbon.lists(list_id).members(user.email_md5)
    .upsert(body: { email_address: user.email_address,
      status: 'subscribed',
      merge_fields: { FNAME: user.firstname, LNAME: user.lastname }
      })
  end
end
