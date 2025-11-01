require 'sequel'
require 'pry'


# user = "EWTUSR02"   ewtusr03
# password = "PASSWTR02" PASSWTR03

hostname = "173.10.10.10"
port = 8471
database = "EWTEST"
user = "EWTUSR02"
password = "PASSWTR02"
dsn = "DATABASE=#{database};HOSTNAME=#{hostname};PORT=#{port};PROTOCOL=TCPIP;UID=#{user};PWD=#{password};"


def test!
  expected = [{:"00001"=>1}]
  actual = DB["select 1 from SYSIBM.SYSDUMMY1"].map{|x| x}

  if expected == actual
    puts " * OK"
  else
    puts " * not OK, expected #{expected} got #{actual}"
  end
end



if Object.const_defined?(:JRUBY_VERSION)
  puts "Testing JRuby with JDBC::AS400"
  require_relative 'lib/jt400.jar'
  jdbc_url = "jdbc:as400://#{hostname}:#{port}/#{database};user=#{user};password=#{password};"
  # DB = Sequel.connect(jdbc_url)
  DB = Sequel.connect(adapter: 'jdbc', url: jdbc_url, after_connect: lambda{|foo| puts foo})
else
  puts "Testing YARV with IBMDB gem"
  require 'ibm_db'
  # DB = Sequel.connect("ibmdb://#{hostname}:#{port}/#{database}?user=#{user}&password=#{password}")
  DB = Sequel.connect(adapter: 'ibmdb', host: hostname, port: port, database: database, user: user, password: password, after_connect: lambda{|foo| puts foo})
end

puts " * connected"

binding.pry

test!
