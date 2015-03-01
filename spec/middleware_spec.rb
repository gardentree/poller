require 'spec_helper'
require 'poller'

class ApplicationMock
  def initialize(&block)
    @block = block
  end

  def call(environment)
    @block.call environment
  end
end

def capture
  source = $stdout
  begin
    $stdout = StringIO.new

    yield

    $stdout.string
  ensure
    $stdout = source
  end
end

describe Poller::Middleware do
  include Rack::Test::Methods

  describe 'when minimum headers' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => "text/html;charset=utf-8"},'']}
      Poller::Middleware.new(mock,'test')
    end

    it do
      log = capture do
        get '/'
      end

      expected = {
        stamp:    Rack::Utils.parse_query(last_response.headers['Set-Cookie'])['stamp'],
        status:   200,
        url:      "http://example.org/",
        address:  "127.0.0.1",
        agent:    nil,
        referer:  nil,
      }
      expect(log).to eq "@[test] #{expected.to_json}\n"
    end
  end
  describe 'when full headers' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => "text/html;charset=utf-8"},'']}
      Poller::Middleware.new(mock,'test')
    end

    it do
      log = capture do
        get('/full',{one: 1},{
          'HTTP_USER_AGENT' => 'Mozilla/5.0',
          'REMOTE_ADDR'     => '8.8.8.8',
          'HTTP_REFERER'    => 'http://example.com/',
        })
      end
      expected = {
        stamp:    Rack::Utils.parse_query(last_response.headers['Set-Cookie'])['stamp'],
        status:   200,
        url:      "http://example.org/full?one=1",
        address:  "8.8.8.8",
        agent:    "Mozilla/5.0",
        referer:  "http://example.com/",
      }
      expect(log).to eq "@[test] #{expected.to_json}\n"
    end
  end
  describe 'when raise exception' do
    let(:app) do
      mock = ApplicationMock.new {raise 'error'}
      Poller::Middleware.new(mock,'test')
    end

    it do
      log = capture do
        expect {
          get '/',nil,{'HTTP_COOKIE' => 'stamp=1234567890;'}
        }.to raise_error
      end

      expected = {
        stamp:    "1234567890",
        status:   nil,
        url:      "http://example.org/",
        address:  "127.0.0.1",
        agent:    nil,
        referer:  nil,
      }
      expect(log).to eq "@[test] #{expected.to_json}\n"
    end
  end
end
