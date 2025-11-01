class Setting < Sequel::Model
  plugin :dirty
  plugin :serialization, :json, :value
end