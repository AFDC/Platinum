class PaymentsController < ApplicationController
  def create
    registration = Registration.find(params['registration_id'])
    unless registration
        redirect_to registrations_user_path(current_user), flash: {error: "Registration not found."} and return 
    end

    price    = registration.price

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
        service_fee:    result.transaction.service_fee_amount,
        currency:       result.transaction.currency_iso_code,
        registration:   registration,
        user:           registration.user,
        league:         registration.league
      })
      registration.status = 'active'
      registration.paid   = true
      registration.save
      redirect_to league_path(registration.league), notice: "Success! You are now confirmed for #{registration.league.name}."
    else
      redirect_to pay_registration_path(registration), flash: {error: "Payment Failed: #{result.message}"}
    end      
  end
end
