class RegistrationPaymentReminderWorker
  include Sidekiq::Worker

  def perform(registration_id)
    logger.info { "Checking to see if registration #{registration_id} has been paid" }
    r = Registration.find(registration_id)

    return unless r.present?

    if r.status == 'accepted'
        logger.info { "#{registration_id} Not yet paid. :(" }
        RegistrationMailer.stale_accepted_registration(registration_id).deliver
    end
  end
end
