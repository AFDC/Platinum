class RegistrationCancellationWorker
  include Sidekiq::Worker

  def perform
    open_leagues = League.not_started

    open_leagues.each do |league|
      expirations   = league.current_expiration_times

      # Set Expirations
      league.registrations.registering.where(acceptance_expires_at: nil).each do |reg|
        gender = reg.gender.to_sym
        next if expirations[gender].nil?

        add_expiration(reg, expirations[gender])
      end

      # Process expirations
      league.registrations.registering.where(:acceptance_expires_at.lte => Time.now).each do |reg|
        expire_registration(reg)
      end

      # Process warning emails
      league.registrations.registering.where(:acceptance_expires_at.lte => 24.hours.from_now, warning_email_sent_at: nil).each do |reg|
        send_warning(reg)
      end
    end    
  end

  def add_expiration(reg, expiration)
    reg.acceptance_expires_at = expiration
    reg.warning_email_sent_at = nil
    if reg.save
        AuditLog.create(
          action: 'AddExpiration',
          league: reg.league,
          registration: reg,
          details: {new_expiration: expiration}
        )
        RegistrationMailer.stale_accepted_registration(reg.id.to_s).deliver
    end
  end

  def expire_registration(reg)
    reg.status                = 'waitlisted'
    reg.signup_timestamp      = Time.now
    reg.acceptance_expires_at = nil
    reg.warning_email_sent_at = nil
    if reg.save
        AuditLog.create(
          action: 'Expire',
          league: reg.league,
          registration: reg
        )
        RegistrationMailer.unpaid_registration_canceled(reg.id.to_s).deliver
    end    
  end

  def send_warning(reg)
    reg.warning_email_sent_at = Time.now
    if reg.save
        RegistrationMailer.stale_accepted_registration(reg.id.to_s).deliver
    end
  end
end
