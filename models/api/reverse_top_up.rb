class ReverseTopUp < DStruct::DStruct

  attributes  strings:  [:access_token, :digest, :api_version, :application_version, :systan, :cashier_pin],
              times:    [:client_datetime],
              integers: [:original_id, :amount, :cashier_id]

  def self.call(context)

    input = new(context.params)

    # models
    merchant_trx     = Transaction[input.original_id]
    terminal         = Terminal     .where(access_token: input.access_token).for_update.first
    cashier          = Cashier      .where(hashed_pin: Utils.digest_SHA512(input.cashier_pin), id: input.cashier_id, active: true, manager: true, terminal_id: terminal&.id).first
    merchant_account = Account      .where(id: terminal&.account_id).for_update.first
    user_trx         = Transaction  .where(parent_id: merchant_trx&.id).first
    user_account     = Account      .where(id: user_trx&.account_id).for_update.first


    # validation
    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :terminal, terminal
        option :merchant_trx, merchant_trx
        option :account, merchant_account
        option :cashier, cashier
        option :input, input

        include CommonTerminalValidators

        def enabled_service?(value)
          account&.top_up
        end

        def valid_digest?(value)
          terminal && value == Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.original_id, input.systan, input.amount)
        end

        def valid_reference?(value)
          merchant_trx && terminal &&
          merchant_trx.services_batch_number  == terminal.services_batch_number && # check current batch
          merchant_trx.id                     == input.original_id &&
          merchant_trx.systan                 == input.systan &&
          merchant_trx.amount                 == input.amount &&
          merchant_trx.transaction_type       == 'top_up_mpos' &&
          merchant_trx.voided                 == false
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

      t = nil
      DB.transaction do

        # new merchant balances
        new_batch_amount = terminal.batch_amount - input.amount
        new_merchant_account_balance = merchant_account.balance # - input.amount # we dont use balance but exposure

        #### debit merchant
        t = Transaction.create({
              account_id: merchant_account.id, terminal_id: terminal.id, systan: input.systan,
              type: 'debit', status: 'approved', transaction_type: 'top_up_reversal_mpos', cashier_id: cashier.id,
              description: "Reversal of #{merchant_trx.id}", balance: new_merchant_account_balance,
              note: "Batch balance: #{new_batch_amount/100.0} #{merchant_account.currency}",
              amount: input.amount, currency: merchant_account.currency, services_batch_number: terminal.services_batch_number,
              client_datetime: input.client_datetime,
              parent_id: merchant_trx.id, operator_code: merchant_trx.operator_code,
              payment_method: merchant_trx.payment_method, payment_method_type: merchant_trx.payment_method_type}.merge(api_and_app_versions))

        # adjust merchant account exposure
        merchant_account.update(exposure_amount: Sequel.-(:exposure_amount, input.amount))

        # update terminal batch amount
        terminal.update({batch_amount: Sequel.-(:batch_amount, input.amount)})

        # void merchant trx
        merchant_trx.update(voided: true)


        # debit user
        user_trx.update(voided: true) # void user trx
        new_user_account_balance = user_account.balance - input.amount

        user_trx = Transaction.create( account_id: user_trx.account_id, user_id: user_trx.user_id,
                            type: 'debit', status: 'approved', transaction_type: 'top_up_reversal',
                            description: "Reversal of #{user_trx.id}", balance: new_user_account_balance,
                            amount: input.amount, currency: user_trx.currency, parent_id: user_trx.id)
        user_account.update(balance: Sequel.-(:balance, input.amount))
      end

      context.render_success({id:       t.id,
                              digest:   Utils.digest_SHA512(terminal.terminal_key, terminal.access_token, input.original_id),
                              cashier:  cashier.full_name}.merge(api_and_app_versions))
    else
      context.render_error(input.errors)
    end
  end
end
