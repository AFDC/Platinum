class PaymentsController < ApplicationController
  def create
    registration = Registration.find(params['registration_id'])
    unless registration
        redirect_to registrations_user_path(current_user), flash: {error: "Registration not found."} and return 
    end

    if registration.is_expired?
      redirect_to register_league_path(registration.league), flash: {error: "You took too long to register. Please try again."}
      return
    end

    price    = registration.price

    # COPIED TO league.rb
    result = Braintree::Transaction.sale(
      amount: price,
      payment_method_nonce: params['payment_method_nonce'],
      channel: 'leagues.afdc.com',
      options: {
        submit_for_settlement: true
      },
      custom_fields: {
        registration_id: registration._id.to_s,
        league_id:       registration.league._id.to_s,
        user_id:         registration.user._id.to_s
      },
      order_id: "registration:#{registration._id.to_s}",
      device_data: params['device_data']
    )

    if result.success?
      PaymentTransaction.create({
        transaction_id: result.transaction.id,
        payment_method: result.transaction.payment_instrument_type,
        amount:         result.transaction.amount,
        currency:       result.transaction.currency_iso_code,
        registration:   registration,
        user:           registration.user,
        league:         registration.league
      })
      registration.paid = true
      registration.activate!

      log_audit('Pay', league: registration.league, registration: registration)

      redirect_to registration_path(registration), notice: "Success! You are now confirmed for #{registration.league.name}."
    else
      redirect_to pay_registration_path(registration), flash: {error: "Payment Failed: #{result.message}"}
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
      redirect_to waitlist_authorize_registration_path(registration), flash: {error: "Authorization Failed: #{result.message}"}
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
