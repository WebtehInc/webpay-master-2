class ReverseBillPayment < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :systan, :cashier_pin],
              times:    [:client_datetime],
              integers: [:original_id, :amount, :cashier_id]

  def self.call(context)

    input = new(context.params)

    # models
    target_trx = Transaction[input.original_id]
    terminal   = Terminal.where(access_token: input.access_token).first
    cashier    = Cashier.where(hashed_pin: Utils.digest_SHA512(input.cashier_pin), id: input.cashier_id, active: true, manager: true, terminal_id: terminal.try(:id)).first
    account    = Account.where(id: terminal.try(:account_id)).first

    # validation
    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :target_trx, target_trx
        option :account, account
        option :cashier, cashier
        option :input, input

        def valid_terminal?(value)
          terminal && terminal.active && account && account.active
        end

        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.original_id, input.systan, input.amount)
        end

        def valid_cashier?(value)
          cashier
        end

        def valid_reference?(value)
          target_trx && terminal &&
          target_trx.services_batch_number  == terminal.services_batch_number && # check current batch
          target_trx.id                     == input.original_id &&
          target_trx.systan                 == input.systan &&
          target_trx.amount                 == input.amount &&
          target_trx.transaction_type       == 'bill_mpos' &&
          target_trx.voided                 == false
        end
      end

      # echoed
      key(:api_version)         { filled? }
      key(:application_version) { filled? }

      # required
      key(:access_token)        { filled? & valid_terminal? }
      key(:digest)              { filled? & valid_digest? }
      key(:systan)              { filled? }
      key(:client_datetime)     { filled? }
      key(:original_id)         { filled? & valid_reference?}
      key(:amount)              { int? }
      key(:cashier_pin)         { filled? & valid_cashier?}
      key(:cashier_id)          { int? }
    end

    input.add_validation_schema validation_schema

    api_and_app_versions = {api_version: input.api_version, application_version: input.application_version}

    if input.valid?

      # customer balance
      customer = Customer.for_update.where(number: target_trx.customer_number, operator_code: target_trx.operator_code).first
      new_customer_balance = customer.balance - input.amount

      t = nil
      DB.transaction do

        # we must be pesimistic here
        account.lock!
        terminal.lock!

        # new monies
        new_batch_amount = terminal.batch_amount - input.amount
        new_exposure_amount = account.exposure_amount - input.amount
        new_account_balance = account.balance # - input.amount # we dont use balance but exposure


        #### debit merchant
        t = Transaction.create({
              account_id: account.id, terminal_id: terminal.id, systan: input.systan,
              type: 'debit', status: 'approved', transaction_type: 'bill_reversal_mpos', cashier_id: cashier.id,
              description: "Reversal of #{target_trx.id}", balance: new_account_balance,
              note: "Batch balance: #{new_batch_amount/100.0} #{account.currency}",
              amount: input.amount, currency: account.currency, services_batch_number: terminal.services_batch_number,
              client_datetime: input.client_datetime,
              parent_id: target_trx.id, operator_code: target_trx.operator_code, customer_number: target_trx.customer_number,
              payment_method: target_trx.payment_method, payment_method_type: target_trx.payment_method_type}.merge(api_and_app_versions))

        # debit merchant account
        account.update(exposure_amount: Sequel.-(:exposure_amount, input.amount))

        # adjust customer balance
        customer.update(balance: Sequel.-(:balance, input.amount))

        # update terminal batch amount
        terminal.update({batch_amount: Sequel.-(:batch_amount, input.amount)})

        # set voided flag to original
        target_trx.update(voided: true)
      end

      # build response
      context.render_success({id:       t.id,
                              digest:   Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.original_id),
                              cashier:  cashier.full_name}.merge(api_and_app_versions))
    else
      context.render_error(input.errors)
    end
  end
end
