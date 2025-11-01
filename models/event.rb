class Event < Sequel::Model

  plugin :serialization, :json, :body, :params, :env

end