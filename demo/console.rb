require 'tty-prompt'
require 'tty-command'

# NOTE: we load webpay in rack file
# load app
# require 'dotenv'
# Dotenv.load
# require './webpay'

unless ENV['WP_ENV'] == 'development'
  puts; puts "WP_ENV must be set to development"; puts
  exit
end

@prompt = TTY::Prompt.new

class CustomPrinter < TTY::Command::Printers::Abstract
  def write(message)
    puts message
  end
end

printer = CustomPrinter
@cmd = TTY::Command.new(printer: printer)

def generate_vouchers
  how_many = @prompt.ask('How many of each?', convert: :int)
  puts
  out, err = @cmd.run("ruby ./demo/generate_vouchers.rb #{how_many}")
  puts
  menu
end

def generate_customers
  out, err = @cmd.run("ruby ./demo/generate_customers.rb")
  puts
  menu
end

def generate_clients
  how_many = @prompt.ask('How many clients?', convert: :int)
  puts
  out, err = @cmd.run("ruby ./demo/generate_clients.rb #{how_many}")
  puts
  menu
end

def generate_cards
  out, err = @cmd.run("ruby ./demo/generate_cards.rb")
  puts
  menu
end

def generate_personal_accounts
  out, err = @cmd.run("ruby ./demo/generate_personal_accounts.rb")
  puts
  menu
end

def generate_business_accounts_and_terminals
  out, err = @cmd.run("ruby ./demo/generate_business_accounts_and_terminals.rb")
  puts
  menu
end

def generate_stocks
  out, err = @cmd.run("ruby ./demo/generate_stocks.rb")
  puts
  menu
end

def generate_personal_transactions
  out, err = @cmd.run("ruby ./demo/generate_personal_transactions.rb")
  puts
  menu
end

def generate_mpos_transactions
  how_many = @prompt.ask('How many per terminal?', convert: :int)
  puts
  out, err = @cmd.run("ruby ./demo/generate_mpos_transactions.rb #{how_many}")
  puts
  menu
end

def generate_services_lodgments
  out, err = @cmd.run("ruby ./demo/generate_services_lodgments.rb")
  puts
  menu
end

def exit_console
  @prompt.say 'Goodbye'
  puts
  exit
end

def run
  puts
  generate_vouchers if @res == 10
  generate_customers if @res == 20

  generate_clients if @res == 30
  generate_cards if @res == 35

  generate_personal_accounts if @res == 40
  generate_business_accounts_and_terminals if @res == 50
  generate_stocks if @res == 55

  generate_personal_transactions if @res == 60
  generate_mpos_transactions if @res == 70

  generate_services_lodgments if @res == 80

  exit_console if @res == 1000
  puts
end

def menu
  puts
  choices = { 'Generate vouchers' => 10,
              'Generate bill paying customers' => 20,
              'Generate users' => 30,
              'Generate cards' => 35,

              'Generate personal accounts' => 40,
              'Generate business accounts and terminals' => 50,
              'Generate stocks' => 55,

              'Generate personal transactions' => 60,
              'Generate mPos transactions' => 70,

              'Generate services lodgments' => 80,

              'Exit console' => 1000}
  @res = @prompt.select("Choose demo task?", choices, per_page: 20)
  run
end

menu
