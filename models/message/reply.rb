class ReplyToMessage < DStruct::DStruct

  attributes  strings: [:title, :body]

  def self.call(message_id, context)

    input = new(context.params)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :message_id, message_id
        option :user_id, context.user_id

        def valid?(value)
          Message.where(id: message_id, user_id: user_id).first
        end
      end

      key(:title)   { filled? & size?(3..40) & valid?}
      key(:body)    { filled? & size?(3..500) }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      Message.create(title: input.title, body: input.body, parent_id: message_id, user_id: context.user_id, sender: 'user')
      context.render_success
    else
      context.render_error(input.errors)
    end
  end

end