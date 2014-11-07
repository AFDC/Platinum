class RegistrationCancellationWorker
  include Sidekiq::Worker

  def perform(registration_id)
    logger.info { "Checking to see if registration #{registration_id} has been paid" }
    r = Registration.find(registration_id)

    if r.status == 'accepted'
        r.status = 'pending'
        r.save
        logger.info { "#{registration_id} Not yet paid. :(" }
        RegistrationMailer.unpaid_registration_cancelled(registration_id).deliver
    end
  end
end
