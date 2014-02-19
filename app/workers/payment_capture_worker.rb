class PaymentCaptureWorker
  include Sidekiq::Worker

  def perform(registration_id)
    logger.info { "Capturing payment for Registration #{registration_id}" }
    r = Registration.find(registration_id)
    if r.capture_payment
      RegistrationMailer.registration_active(registration_id).deliver
    end
  end
end
