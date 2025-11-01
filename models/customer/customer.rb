class Customer < Sequel::Model

  many_to_one :operator, key: :operator_code

  PUBLIC_ATTRS = [:id, :operator_code, :number, :balance, :currency, :creted_at]

  def public_values
    values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  end

end