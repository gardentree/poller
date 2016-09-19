$LOAD_PATH << File.expand_path("../lib", __FILE__)
require 'sinatra'
require File.expand_path("../lib/poller", __FILE__)

get '/' do
  'Hello, World !'
end

get '/hello/:name' do |n|
  "Hello #{n}!"
end

get '/hello/自宅で簡単！ペンキのシミの落とし方' do
  "test"
end

use Poller::Middleware, "", {}
run Sinatra::Application
