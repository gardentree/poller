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

  before do
    allow(Time).to receive_message_chain(:now,:utc).and_return(Time.new(2015,12,10,23,17,24).utc)
  end

  describe 'when minimum headers' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => "text/html;charset=utf-8"},'']}
      Poller::Middleware.new(mock,'target','test')
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
        scene:    'test',
        time:     "2015-12-10 14:17:24 UTC",
      }
      expect(log).to eq({target: expected}.to_json + "\n")
    end
  end
  describe 'when full headers' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => "text/html;charset=utf-8"},'']}
      Poller::Middleware.new(mock,'target','test')
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
        scene:    'test',
        time:     "2015-12-10 14:17:24 UTC",
      }
      expect(log).to eq({target: expected}.to_json + "\n")

      expect(cookies['referer']).to eq('http://example.com/')
    end
  end
  describe 'when exist referer and already referer' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => "text/html;charset=utf-8"},'']}
      Poller::Middleware.new(mock,'target','test')
    end

    it do
      log = capture do
        get('/',nil,{
          'HTTP_REFERER'  => 'http://example.com/',
          'HTTP_COOKIE'   => "referer=#{URI.escape 'http://referer.com/'};",
        })
      end

      cookies = Rack::Utils.parse_query(last_response.headers['Set-Cookie'].split("\n").join("&"))

      expected = {
        stamp:    cookies['stamp'],
        status:   200,
        url:      "http://example.org/",
        address:  "127.0.0.1",
        agent:    nil,
        referer:  "http://example.com/",
        scene:    'test',
        time:     "2015-12-10 14:17:24 UTC",
      }
      expect(log).to eq({target: expected}.to_json + "\n")

      expect(cookies['referer']).to be_nil
    end
  end
  describe 'when raise exception' do
    let(:app) do
      mock = ApplicationMock.new {raise 'error'}
      Poller::Middleware.new(mock,'target','test')
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
        scene:    'test',
        time:     "2015-12-10 14:17:24 UTC",
      }
      expect(log).to eq({target: expected}.to_json + "\n")
    end
  end
  describe 'when content type is nil' do
    let(:app) do
      mock = ApplicationMock.new {[200,{"Content-Type" => nil},'']}
      Poller::Middleware.new(mock,'target','test')
    end

    it do
      log = capture do
        get '/'
      end

      expect(log).to eq ""
    end
  end
end
