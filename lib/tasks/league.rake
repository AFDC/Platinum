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
                        RegistrationMailer.unpaid_registration_canceled(r.id.to_s).deliver
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

    desc 'Refund all Registrations'
    task :refund, [:league_id] => [:environment] do |t, args|
        league = League.find(args[:league_id])
        if league == nil
            puts "League not found with ID '#{args[:league_id]}'"
            next
        end

        puts "Cancellations for #{league.name}"
        msg = []
        league.registrations.each do |reg|
            msg = ["[#{reg._id}]"]
            msg << cancel_reg(reg)
            msg << "(#{reg.user.name})"
            puts msg.join(' ')
        end
    end

    def cancel_reg(reg)
        if reg.status == 'canceled'
            return 'Previously Canceled'
        end

        if reg.status != 'active'
            reg.cancel
            return 'Canceled, No Refund Needed'
        end

        if reg.comped == true
            reg.status = 'canceled'
            reg.save
            return 'Comped Registration Canceled'
        end

        # If we get here, the registration is active and not comped

        begin
            if reg.refund! == false
                return 'Refund or registration update Failed'
            end
        rescue StandardError => e
            return "Error: '#{e.message}'"
        end

        return 'Registration Refunded & Canceled'
    end
end
