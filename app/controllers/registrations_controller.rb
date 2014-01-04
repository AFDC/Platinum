class RegistrationsController < ApplicationController
    before_filter :load_registration_from_params, only: [:cancel, :edit, :update, :checkout, :approved, :cancelled, :show]
    filter_access_to [:edit, :update, :show, :checkout, :cancel], attribute_check: true

    def create
        # reg_params = params[:registration]

        populate_registration Registration.new
    end

    def edit
    end

    def update
        populate_registration @registration
    end

    def show
    end

    def cancel
        if @registration.void_authorization
            redirect_to registrations_user_path(@registration.user), notice: "Your registration has been cancelled." and return
        end

        redirect_to registrations_user_path(@registration.user), flash: {error: "Cancelling your registration failed."}
    end

    def checkout
        if @registration.league.nil?
            redirect_to registrations_user_path(current_user), flash: {error: "League not found for that registration."}
            return
        end

        if @registration.user.nil?
            redirect_to registrations_user_path(current_user), flash: {error: "User not found for that registration."}
            return
        end

        price = '%.2f' % @registration.league.price

        desc = "AFDC Registration Fee for #{@registration.league.name}. [#{@registration._id}]"

        payment = PayPal::SDK::REST::Payment.new({
            intent: 'authorize',
            payer: {payment_method: 'paypal'},
            transactions: [{amount: {currency: 'USD', total: price}, description: desc}],
            redirect_urls: {return_url: approved_registration_url(@registration), cancel_url: cancelled_registration_url(@registration)}
        })

        begin
            payment.create
        rescue 
            redirect_to registrations_user_path(current_user), flash: {error: "There was an error talking to PayPal, please try again or contact webmaster@afdc.com."}
            return
        end
        
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

    def populate_registration(reg)
        reg_params = params[:registration]

        unless ['25%', '50%', '75%', '100%'].include?(reg_params[:gen_availability])
            redirect_to register_league_path(reg.league), notice: "You must select and attendance percentage"
            return
        end

        unless ['1', '2', '3', '4', '5', '6', '7', '8', '9'].include?(reg_params[:self_rank])
            redirect_to register_league_path(reg.league), notice: "You must select a rank for yourself"
            return
        end

        unless ['Runner', 'Thrower', 'Both'].include?(reg_params[:player_strength])
            redirect_to register_league_path(reg.league), notice: "You must select a primary role"
            return
        end

        unless reg_params[:waiver_accepted] == '1' || reg.persisted?
            redirect_to register_league_path(reg.league), notice: "You must accept the waiver to register"
            return
        end

        if reg.new_record?
            reg.waiver_acceptance_date = Time.now
            reg.league = League.find(reg_params[:league_id])
            reg.signup_timestamp = Time.now
            reg.payment_timestamps[:pending] = Time.now
            reg.user = current_user
            reg.status = 'pending'
            reg.paid = false
        end

        reg.availability = {
            general: reg_params[:gen_availability],
            attend_tourney_eos: (reg_params[:eos_availability] == '1')
        }
        reg.gender = reg.user.gender
        reg.player_strength = reg_params[:player_strength]
        reg.secondary_rank_data = {self_rank: reg_params[:self_rank]}
        reg.notes = reg_params[:notes]
        reg.pair_id = reg_params[:pair_id].length >= 2 ? reg_params[:pair_id][1] : nil
        reg.user_data = {
            birthdate: reg.user.birthdate,
            firstname: reg.user.firstname,
            middlename: reg.user.middlename,
            lastname: reg.user.lastname,
            gender: reg.user.gender,
            height: reg.user.height,
            weight: reg.user.weight
        }

        if reg.save
            if reg.status == 'active' || reg.status == 'authorized' || current_user._id != reg.user._id
                redirect_to registrations_user_path(reg.user), notice: 'Update successful'   
            else     
                redirect_to checkout_registration_path(reg)
            end
        else
            redirect_to registrations_user_path(reg.user), notice: new_reg.errors
        end

    end

    def load_registration_from_params
        begin
            @registration = Registration.find(params[:id])
        rescue
            redirect_to registrations_user_path(current_user), flash: {error: "Could not load registration for ID '#{params[:id]}'."}
        end
    end
end
