class PaymentCaptureWorker
  include Sidekiq::Worker

  def perform(registration_id)
    logger.info { "Capturing payment for Registration #{registration_id}" }
    r = Registration.find(registration_id)
    r.capture_payment
  end
end