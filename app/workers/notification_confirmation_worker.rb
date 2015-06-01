class NotificationConfirmationWorker
  include Sidekiq::Worker

  def perform(notification_method_id)
    notification_method = NotificationMethod.find(notification_method_id)
    raise "Method not found for #{notification_method_id}" unless notification_method
    
    return if notification_method.confirmed?

    if notification_method.method == 'text'
        twilio_client = Twilio::REST::Client.new
        twilio_client.account.messages.create({ 
            from: ENV['twilio_number'], 
            to:   notification_method.target,
            body: "Hello from the AFDC! Your confirmation code is #{notification_method.confirmation_code}. Please email help@afdc.com if you have any trouble."
        })
    end

    if notification_method.method == 'email'
        NotificationMailer.confirm_email(notification_method._id.to_s).deliver
    end
  end
end
