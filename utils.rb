require 'facets/hash/traverse'

class Object
  def try(m, *args, &block)
    if is_a?(NilClass)
      self
    else
      send(m, *args, &block)
    end
  end
end

class Hash
  def slice *keys
    select{|k| keys.member?(k)}
  end

  def except *keys
    reject{|k| keys.member?(k)}
  end

  def to_desc(delimiter = ' | ')
    reduce([]){|a, (k, v)| a << "#{k}: #{v}"}.join(delimiter)
  end

  def mask_sensitive_attrs(*extra_attrs)
    sensitive_attrs = SENSITIVE_ATTRS + extra_attrs
    filtered_value = '[filtered]'
    traverse{|k,v| [k, sensitive_attrs.any?(k.to_s) ? filtered_value : v]}
  end
end

class Array
  def stringify
    reduce([]){|a,t| a << t.to_s}
  end
end

class String
  def in_groups_by(n, delimiter = ' ')
    (scan /.{1,#{n}}/).join(delimiter)
  end
end


module Utils
  module_function

  def generate_random_token
    ROTP::Base32.random_base32
  end

  def error_handler(e, context)
    time_spent = Time.now - context.instance_variable_get(:@start_time)
    Mailer.sendmail("/app/exception", e, context, time_spent)
    event_hash = {
      type: 'exception', title: "[#{time_spent} sec] #{e.class}: #{e.message[0..200]}", body: e.backtrace,
      params: context.request.params.mask_sensitive_attrs,
      env: context.env.mask_sensitive_attrs('roda.json_params')
    }
    Event.create(event_hash)
    LOGGER.error "APP ERROR:\n"
    LOGGER.error event_hash[:title]
    LOGGER.error event_hash[:body].join("\n")
    LOGGER.error self.format_hash[event_hash[:params]]
    LOGGER.error self.format_hash[event_hash[:env]]
  end

  def format_hash
    lambda{|h| h.map{|k, v| "#{k.inspect} => #{v.inspect}"}.sort.join("\n")}
  end

  def save_file_from_base64_upload(data_url)
    regexp = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m
    data_uri_parts = data_url.match(regexp) || []
    extension = MIME::Types[data_uri_parts[1]].first.preferred_extension
    file_name = "#{Utils.generate_random_token}.#{extension}"
    file_path =  "#{WebPay.opts[:upload_path]}/#{file_name}"
    data = Base64.decode64(data_uri_parts[2])
    File.open(file_path, 'wb'){ |file| file.write(data)}
    [file_name, file_path, extension, data.size]
  end

  def random_pin(size)
    ('0' * size + rand(('9' * size).to_i).to_s)[-size..-1]
  end

  def digest_SHA512(*parts)
    Digest::SHA512.hexdigest(parts.join(''))
  end
end
