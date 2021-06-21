class RegistrationCancellationWorker
  include Sidekiq::Worker

  def perform
    open_leagues = League.not_started
    logger.info "RegistrationCancellationWorker performing job... (open leagues: #{open_leagues.count})"

    open_leagues.each do |league|
      logger.info "Processing Cancellations for #{league.name} (count: #{league.registrations.expired.where(:status.ne => "expired").count})"

      # Process expirations
      league.registrations.expired.where(:status.ne => "expired").each do |reg|
        logger.info "Cancelling registration for #{reg.user_data['firstname']} #{reg.user_data['lastname']}"
        expire_registration(reg)
      end

      # Process warning emails
      league.registrations.registering.where(:acceptance_expires_at.lte => 24.hours.from_now, warning_email_sent_at: nil).each do |reg|
        # send_warning(reg)
      end
    end    
  end

  def expire_registration(reg)
    reg.status                = 'expired'
    reg.expires_at            = nil
    reg.warning_email_sent_at = nil
    reg.save!(validate: false) # registrations that haven't been filled out yet won't be valid

    AuditLog.create(
      action: 'Expire',
      league: reg.league,
      registration: reg
    )

    RegistrationMailer.unpaid_registration_cancelled(reg.id.to_s).deliver
  end

  def send_warning(reg)
    reg.warning_email_sent_at = Time.now
    if reg.save
        RegistrationMailer.stale_accepted_registration(reg.id.to_s).deliver
    end
  end
end
