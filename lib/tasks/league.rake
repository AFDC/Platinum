namespace :league do
    desc 'Expire old, accepted registrations and send warning emails'
    task expire_registrations: :environment do
        League.not_started.each do |l|
            print "#{l.name} (#{l.id})\n"
            expirations = l.current_expiration_times

            l.registrations.accepted.each do |r|
                gender = r.gender.to_sym

                if expirations[gender] && r.acceptance_expires_at.nil?
                    print "\tAdding Expiration to: #{r.id}\n"
                    r.acceptance_expires_at = expirations[gender]
                    r.warning_email_sent_at = nil
                    if r.save
                        RegistrationMailer.stale_accepted_registration(r.id.to_s).deliver
                    end
                    next
                end

                next unless r.acceptance_expires_at

                if r.acceptance_expires_at < Time.now
                    print "\tExpiring: #{r.id}\n"
                    r.status           = 'pending'
                    r.signup_timestamp = Time.now
                    r.acceptance_expires_at = nil
                    r.warning_email_sent_at = nil
                    if r.save
                        RegistrationMailer.unpaid_registration_cancelled(r.id.to_s).deliver
                    end
                    next
                end

                if r.warning_email_sent_at.nil? && r.acceptance_expires_at < 24.hours.from_now
                    print "\tSending reminder for: #{r.id}\n"
                    r.warning_email_sent_at = Time.now
                    if r.save
                        RegistrationMailer.stale_accepted_registration(r.id.to_s).deliver
                    end
                    next
                end
                print "\tNo action needed: #{r.id}\n"
            end
        end
    end
end