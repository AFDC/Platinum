class PlayerRegistrar
    attr_reader :league
    attr_reader :player
    attr_reader :registration

    def initialize(league, player)
        @league = league
        @player = player

        @registration = league.registration_for(player)
    end

    def open?
        return false unless league.registration_open_for?(player)
        return false unless league.gender_permitted?(gender)

        true
    end

    def gender
        player.gender
    end

    def needs_profile_update?
        !player.valid?
    end

    def initialize_registration!
        @registration ||= Registration.new(league: league, user: player)

        queue_registration!

        if (has_waitlist? || is_full?)
            registration.status = 'registering_waitlisted'
            registration.save!(validate: false)
            return registration
        end

        registration.status     = 'registering'
        registration.expires_at = league.current_expiration_time
        registration.save!(validate: false)        

        return registration
    end

    def queue_registration!
        registration.status     = 'queued'
        registration.expires_at = 10.minutes.from_now

        if (registration.queued_at.nil? || registration.is_expired?)
            registration.queued_at  = Time.now
        end

        registration.save!(validate: false)
    end

    def has_waitlist?
        league.registrations.waitlisted.where(gender: gender).count > 0
    end
    
    def is_full?
        league_regs = league.registrations.where(gender: gender)

        limit       = league.gender_limit(gender)
        active      = league_regs.active.count
        registering = league_regs.registering.count
        earlier_q   = registration.count_earlier_queued_registrations

        limit <= active + registering + earlier_q
    end
end
