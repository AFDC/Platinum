namespace :league do
    desc 'Expire stale registrations'
    task expire_registrations: :environment do
        League.expire_stale_registrations
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
