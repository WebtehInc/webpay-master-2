require 'tty-prompt'
require 'tty-command'

# load env
require 'dotenv'
Dotenv.load

# load cache store
require './models/memory_cache/store'

# load app
require './webpay'

# load SimpleRodaContext to emulate roda req/resp
# require './models/simple_roda_context'

DB.loggers = [] # don't log sql

@prompt = TTY::Prompt.new
@models = [Page, Operator, Product, Fee, Limit, Setting]

Operator.instance_eval  {serializer file_name: "operators.json",  primary_key: :code}
Setting.instance_eval   {serializer file_name: "settings.json",   primary_key: :name}

@models.each do |m|
  next if [Operator, Setting].include?(m)
  m.instance_eval {serializer file_name: "#{m.to_s.downcase}s.json"}
end

def print_model_status(model)
  json_file = model.send(:load_from_file)

  db_count = model.send(:count)
  db_timestamp = model.order(:updated_at).send(:last).try(:created_at) || 'none'

  file_count = json_file[:data].size
  file_timestamp = json_file[:ctime]

  db_empty = db_count == 0

  if db_empty
    status = {type: :error, text: 'Table is empty!'} if db_empty
  else
    needs_update = file_timestamp > db_timestamp
    up_to_date = file_timestamp < db_timestamp
    status = {type: :warn, text: 'Needs update.'} if !db_empty and needs_update
    status = {type: :ok, text: 'Up to date.'} if !db_empty and up_to_date
  end

  if !db_empty
    @prompt.ok("#{model}s ✔")
  elsif
    @prompt.error("#{model}s ✗")
  end
  @prompt.ok("=> db count: #{db_count} | db timestamp: #{db_timestamp}")
  @prompt.ok("=> file count: #{file_count} | file timestamp: #{file_timestamp}")
  @prompt.send(status[:type], "Summary: #{status[:text]}")
end


def print_models_statuses
  @models.each do |m|
    print_model_status m
    puts
  end
end

def exit_console
  @prompt.say 'Goodbye'
  puts
  exit
end

def update_pos_download_config
  DownloadConfig.reset!
  resp = DownloadConfig.call
  @prompt.ok('Download configuration updated:')
  @prompt.ok(resp.inspect)
end

def run
  puts
  exit_console if @res == :exit

  confirm = @prompt.yes?('Please confirm action.')

  # model updates
  model = @res
  model.send(:save_to_db_from_file!, true) if model.respond_to?(:save_to_db_from_file!) and confirm

  # other
  update_pos_download_config if @res == :update_pos_download_config and confirm

  puts
  # print_models_statuses
  puts
  menu
end

def menu
  choices = @models.inject({}) {|a, model| a.update("Import #{model}s" => model)}
  @res = @prompt.select("Choose task?", choices.merge(
    'Update POS download configuration' => :update_pos_download_config,
    'Exit console' => :exit), per_page: 20)
  run
end

puts
print_models_statuses
puts
menu
