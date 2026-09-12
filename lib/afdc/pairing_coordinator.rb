# TODO: Exclude already-paired players from search results

class PairingCoordinator
    class PairChanged < StandardError; end
    attr_reader :league

    def initialize(league)
        @league = league
    end
    
    def request_pair(source_player, target_player)
        # puts "Requesting pair..."
        src_user = load_user(source_player)
        # puts "\t Source user loaded (#{source_player} => #{src_user&.name})"
        tgt_user = load_user(target_player)
        # puts "\t Source user loaded (#{target_player} => #{tgt_user&.name})"

        return false if src_user.nil?

        src_reg = @league.registration_for(src_user)
        tgt_reg = @league.registration_for(tgt_user)

        # Check if either player is already paired
        return false if src_reg&.linked?
        return false if tgt_reg&.linked?
        # puts "\t Neither user is paired/cored yet"

        # Cancel all outstanding sent pair requests:
        src_reg.sent_invitations.outstanding.update_all(status: "canceled")
        return true if tgt_user.nil?

        # Accept outstanding pair invite from the target player, if it exists
        if tgt_reg.present? && tgt_reg.sent_invitations.outstanding.where(recipient: src_user).exists?
            tgt_reg.sent_invitations.outstanding.where(recipient: src_user).first.accept
            # puts "\t Pair Successful!"
            return true
        end

        if src_reg.sent_invitations.where(recipient: tgt_user).exists?
            src_reg.sent_invitations.where(recipient: tgt_user).update(status: "sent")
            # puts "\t Reusing old Invite"
            return true
        end
        Invitation.create!(type: "pair", sender: src_user, recipient: tgt_user, handler: @league)
    end

    def excluded_players
        cored_list = RegistrationGroup.where(league: @league).all.inject([]) {|list, grp| list + grp.member_ids}
        captain_list = Team.where(league: @league).all.inject([]) {|list, team| list + team.captains.map(&:id)}
        paired_list = @league.registrations.where(:pair_id.ne => nil).all.inject([]) {|list, reg| list.append(reg.user_id)}
        (cored_list + captain_list + paired_list).to_set.to_a.map(&:to_s)
    end

    def break_pair(registration, expected_pair_id)
        unless registration.league_id == league.id && registration.pair_id.present? &&
            registration.pair_id.to_s == expected_pair_id.to_s
            raise PairChanged, 'This pair has changed. Refresh the player list and try again.'
        end

        partner_registration = league.registrations.where(user_id: registration.pair_id).first
        if partner_registration && partner_registration.pair_id.present? && partner_registration.pair_id != registration.user_id
            raise PairChanged, 'These players are no longer paired with each other. Refresh the player list and try again.'
        end

        details = {
            user_ids: [registration.user_id.to_s, registration.pair_id.to_s],
            registration_ids: [registration.id.to_s, partner_registration&.id&.to_s].compact
        }

        # Remove obsolete pair fields rather than leaving null references behind.
        # Scope each update to the expected partner, and bypass unrelated form validations.
        selectors = [{ _id: registration.id, pair_id: registration.pair_id }]
        if partner_registration && partner_registration.pair_id == registration.user_id
            selectors << { _id: partner_registration.id, pair_id: registration.user_id }
        end
        league.registrations.any_of(*selectors).unset(:pair_id)
        league.touch
        details
    end

    private

    def load_user(identifier)
        if identifier.is_a?(User)
            return identifier
        end

        if identifier.is_a?(Registration)
            return identifier.user
        end

        if identifier.is_a?(String) or identifier.is_a?(BSON::ObjectId)
            return User.find(identifier)
        end
    end
end
