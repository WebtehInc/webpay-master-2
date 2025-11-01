# set MEMORY_STORE as memcached client
require 'dalli'
begin
  puts "* Setting MEMORY_STORE as memcached client"
  MEMORY_STORE = Dalli::Client.new(ENV['MEMCACHED_URL'] || 'localhost:11211', :namespace => 'webpay', :compress => true)
  MEMORY_STORE.set('test', true)
rescue
  puts 'ERROR: Memcached client is not runing.'
  exit
end

MemoryStore = MEMORY_STORE

# each setting is loaded when needed in cache module
# puts "* Loading settings into memory cache ..."
# DB[:settings].all do |setting|
#   MEMORY_STORE.set(setting[:name], JSON.parse(setting[:value])) # deserialize json string from db, ie. '[item1, item 2 ...]'
#   puts "  => #{setting[:name]}: #{setting[:value]}"
# end
