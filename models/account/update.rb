class UpdateAccount < DStruct::DStruct

  attributes strings: [:title]#, booleans: [:active]

  def self.call(account_id, context)

    update_account = new(context.params)
    update_account.add_validation_schema MyValidationSchema

    if update_account.valid?
      context.render_success if Account.update(account_id, update_account.to_h, context.user_id)
    else
      context.render_error(update_account.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:title)   { filled? & size?(3..40) }
    # key(:active)  { bool? }
  end

end