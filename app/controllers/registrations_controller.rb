class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:checkout, :approved, :cancelled]

    def create
        reg_params = params[:registration]

        new_reg = Registration.new

        new_reg.league = League.find(reg_params[:league_id])
        new_reg.user = current_user

        if (Registration.where(league_id: new_reg.league._id, user_id: current_user._id).count > 0)
            redirect_to registrations_user_path(current_user), notice: "You've already registered for that league."
            return
        end

        unless new_reg.league
            redirect_to leagues_path, notice: 'League not found.'
            return
        end

        unless ['25%', '50%', '75%', '100%'].include?(reg_params[:availability])
            redirect_to register_league_path(new_reg.league), notice: "You must select and attendance percentage"
            return
        end

        unless ['1', '2', '3', '4', '5', '6', '7', '8', '9'].include?(reg_params[:self_rank])
            redirect_to register_league_path(new_reg.league), notice: "You must select a rank for yourself"
            return
        end

        unless ['Runner', 'Thrower', 'Both'].include?(reg_params[:player_strength])
            redirect_to register_league_path(new_reg.league), notice: "You must select a primary role"
            return
        end

        unless reg_params[:waiver_accepted] == '1'
            redirect_to register_league_path(new_reg.league), notice: "You must accept the waiver to register"
            return
        end

        # This is ugly, oh well.
        new_reg.availability = {general: reg_params[:availability]}
        new_reg.gender = current_user.gender
        new_reg.paid = false
        new_reg.player_strength = reg_params[:player_strength]
        new_reg.secondary_rank_data = {self_rank: reg_params[:self_rank]}
        new_reg.signup_timestamp = Time.now
        new_reg.payment_timestamps[:pending] = Time.now
        new_reg.status = 'pending'
        new_reg.user_data = {
            birthdate: current_user.birthdate,
            firstname: current_user.firstname,
            middlename: current_user.middlename,
            lastname: current_user.lastname,
            gender: current_user.gender,
            height: current_user.height,
            weight: current_user.weight
        }

        if new_reg.save
            redirect_to checkout_registration_path(new_reg)
        else
            redirect_to registrations_user_path(current_user), notice: new_reg.errors
        end
    end

    def checkout
        if @registration.league.nil?
            redirect_to registrations_user_path(current_user), flash: {error: "League not found for that registration."}
            return
        end

        if @registration.user.leanil?
            redirect_to registrations_user_path(current_user), flash: {error: "User not found for that registration."}
            return
        end

        price = '%.2f' % @registration.league.price

        desc = "#{@registration.user.name}'s AFDC Registration Fee for #{@registration.league.name}. Registration ID #{@registration._id}."

        payment = PayPal::SDK::REST::Payment.new({
            intent: 'authorize',
            payer: {payment_method: 'paypal'},
            transactions: [{amount: {currency: 'USD', total: price}, description: desc}],
            redirect_urls: {return_url: approved_registration_url(@registration), cancel_url: cancelled_registration_url(@registration)}
        })

        payment.create
        
        if payment.id
            @registration.payment_id = payment.id
            @registration.payment_timestamps[:created] = Time.now
        end

        @registration.paypal_responses.push(JSON.parse(payment.to_json()))
        @registration.save()

        # payment state options: created, approved, failed, canceled, or expired
        if payment.state == 'created'
            redirect_url = payment.links.find{|v| v.method == 'REDIRECT'}.href
            Rails.logger.info "Payment[#{payment.id}]"
            Rails.logger.info "Redirect: #{redirect_url}"            
            redirect_to redirect_url
        elsif payment.state == 'approved'
            redirect_to registrations_user_path(current_user), notice: "That registration has already been authorized."
        elsif payment.errors
            Rails.logger.error payment.errors.inspect
            redirect_to registrations_user_path(current_user), flash: {error: payment.errors.inspect}
        else
            redirect_to registrations_user_path(current_user), flash: {error: "Unknown error for registration #{@registration._id}"}
        end
    end

    def approved
        token = params[:token]
        payer_id = params[:PayerID]

        begin
            payment = PayPal::SDK::REST::Payment.find(@registration.payment_id)
        rescue
            redirect_to registrations_user_path(current_user), flash: {error: "Payment not found for registration #{@registration._id}"}
        end

        if payment.execute(payer_id: payer_id)
            @registration.paypal_responses.push(JSON.parse(payment.to_json()))
            @registration.payment_timestamps[:authorized] = Time.now
            @registration.status = 'authorized'
            @registration.save()

            redirect_to registrations_user_path(@registration.user), notice: "Authorization successful!"
        else
            redirect_to registrations_user_path(current_user), flash: {error: payment.errors.inspect}
        end
    end


    def cancelled
        redirect_to registrations_user_path(current_user), flash: {error: "Your purchase has been cancelled"}
    end

    private

    def load_registration_from_params
        begin
            @registration = Registration.find(params[:id])
        rescue
            redirect_to registrations_user_path(current_user), flash: {error: "Could not load registration for ID '#{params[:id]}'."}
        end
    end
end
