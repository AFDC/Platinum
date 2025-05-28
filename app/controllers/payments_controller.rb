class PaymentsController < ApplicationController
  def create
    price = 0
    donation_amount = 0
    league_registration = nil
    pickup_registration = nil
    league = nil
    user = nil
  

    if params['type'] == 'pickup'
      pickup_registration = PickupRegistration.find(params['pickup_registration_id'])
      unless pickup_registration
        redirect_to registrations_user_path(current_user), flash: {error: "Pickup Registration not found."} and return 
      end

      if pickup_registration.assigned_date < Date.today
        redirect_to leauge_path(pickup_registration.league), flash: {error: "This pickup opportunity has passed."} and return
      end

      league = pickup_registration.league
      user = pickup_registration.user
      price = pickup_registration.price
    else
      league_registration = Registration.find(params['registration_id'])
      unless league_registration
          redirect_to registrations_user_path(current_user), flash: {error: "Registration not found."} and return 
      end

      if league_registration.is_expired?
        redirect_to register_league_path(league_registration.league), flash: {error: "You took too long to register. Please try again."}
        return
      end

      donation = Donation.new(amount: params[:donation_amount])

      if league_registration.league.solicit_donations? && donation.valid?
        donation_amount = donation.amount
        donation.user = league_registration.user
        donation.registration = league_registration
      end

      league = league_registration.league
      user = league_registration.user
      price = league_registration.price
    end

    generic_registration_id = (league_registration || pickup_registration)._id.to_s

    # COPIED TO league.rb
    result = Braintree::Transaction.sale(
      amount: price + donation_amount,
      payment_method_nonce: params['payment_method_nonce'],
      channel: 'leagues.afdc.com',
      options: {
        submit_for_settlement: true
      },
      custom_fields: {
        donation_amount: donation_amount,
        registration_id:        generic_registration_id, # this could be a league registration or a pickup registration
        league_id:              league._id.to_s,
        user_id:                user._id.to_s
      },
      order_id: "registration:#{generic_registration_id}",
      device_data: params['device_data']
    )

    if result.success?
      pt = PaymentTransaction.create({
        transaction_id:      result.transaction.id,
        payment_method:      result.transaction.payment_instrument_type,
        amount:              result.transaction.amount,
        currency:            result.transaction.currency_iso_code,
        registration:        league_registration,
        pickup_registration: pickup_registration,
        user:                user,
        league:              league
      })

      if donation_amount > 0
        donation.payment_transaction = pt
        donation.save
        log_audit('Donate', league: league, registration: league_registration)
      end

      if league_registration
        league_registration.paid = true
        league_registration.activate!

        log_audit('Pay', league: league, registration: league_registration)
        
        redirect_to registration_path(league_registration), notice: "Success! You are now confirmed for #{league.name}." and return
      end

      if pickup_registration
        log_audit('PickupPay', league: league)

        if !pickup_registration.activate_and_notify
          redirect_to pickup_registration_league_path(league, pickup_registration_id: pickup_registration._id), flash: {error: "Error updating pickup registration."} and return
        end

        redirect_to league_path(league), notice: "Success! You are now confirmed for #{league.name}." and return
      end

      raise "Unknown registration type for txid: #{result.transaction.id}."
    else
      if league_registration
        redirect_to pay_registration_path(league_registration), flash: {error: "Payment Failed: #{result.message}"}
      else
        redirect_to pay_pickup_registration_path(pickup_registration), flash: {error: "Payment Failed: #{result.message}"}
      end
    end      
  end

  def pre_authorize
    registration = Registration.find(params['registration_id'])
    unless registration
      redirect_to registrations_user_path(current_user), flash: {error: "Registration not found."} and return 
    end

    if registration.is_expired?
      redirect_to register_league_path(registration.league), flash: {error: "You took too long to register. Please try again."}
      return
    end

    price = registration.price

    result = Braintree::Transaction.sale(
      amount: price,
      payment_method_nonce: params['payment_method_nonce'],
      channel: 'leagues.afdc.com',
      options: {
        submit_for_settlement: false
      },
      custom_fields: {
        registration_id: registration._id.to_s,
        league_id:       registration.league._id.to_s,
        user_id:         registration.user._id.to_s
      },
      order_id: "registration:#{registration._id.to_s}",
      device_data: params['device_data']
    )

    if result.success? == false
      error_msg = "Authorization Failed: #{result.message}"
      Bugsnag.notify(StandardError.new(error_msg))
      redirect_to waitlist_authorize_registration_path(registration), flash: {error: error_msg}
      return
    end

    tx = result.transaction

    Braintree::Transaction.void(tx.id)

    payment_token = tx.credit_card_details.token ||
      tx.transaction.apple_pay_details.token ||
      tx.paypal_details.token ||
      tx.samsung_pay_card_details.token ||
      tx.venmo_account_details.token ||
      tx.visa_checkout_card_details.token
    
    if payment_token.nil?
      err = "Stored payment method not found, please try again or contact help@afdc.com."
      redirect_to waitlist_authorize_registration_path(registration), flash: {error: "#{err} (#{result.message})"}
      return
    end
    
    registration.waitlist({auth_tx_id: result.transaction.id, stored_payment_token: payment_token})

    redirect_to registration_path(registration), notice: "Success! You are now on the waitlist for #{registration.league.name}."
  end
end
