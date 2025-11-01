class ChangeCardPin < DStruct::DStruct

  attributes  strings: [:pin]

  def self.call(card_id, context)

    input = new(context.params)
    card = Card[card_id]

    validation_schema = Dry::Validation.Form do
      key(:pin) { filled? & size?(4)}
    end

    input.add_validation_schema validation_schema

    if input.valid?
      # TODO: encrypt pin block
      pin_block = input.pin

      updating_attrs = {pin_block: pin_block}
      updating_attrs.merge!(state: 'activated', active: true) if card.state == 'pending' # initial activation

      card.add_audit_message(context.user_id, 'Card activated')
      context.render_success Card.update(card_id, updating_attrs, context.user_id, non_audited_attrs = [:pin_block]).public_values
    else
      context.render_error(input.errors)
    end
  end

end
