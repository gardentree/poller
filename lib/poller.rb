require "poller/version"
require 'active_support'
require 'active_support/core_ext'

module Poller
  class Middleware
    def initialize(application,table,options={})
      @application  = application
      @table        = table
      @options      = options
    end
    def call(environment)
      request = Rack::Request.new(environment)
      stamp = request.cookies['stamp']||SecureRandom.hex
      begin
        status,header,body = @application.call(environment)

        response = Rack::Response.new(body,status,header)
        response.set_cookie('stamp',create_cookie(stamp))

        success(stamp,request,response)

        response.finish
      rescue => exception
        failure(stamp,request)

        raise exception
      end
    end

    private
      def create_cookie(stamp)
        cookie = {value: stamp}
        cookie[:path]     = @options[:path] if @options[:path]
        cookie[:expires]  = Time.zone.now + @options[:expires] if @options[:expires]
        cookie[:domain]   = @options[:domain] if @options[:domain]

        cookie
      end

      def success(stamp,request,response)
        return if response.redirection?
        return if response.ok? && !response.content_type.split(';').include?('text/html')

        poll stamp,request,response.status
      end
      def failure(stamp,request)
        poll stamp,request,nil
      end
      def poll(stamp,request,status)
        log = {
          stamp:    stamp,
          status:   status,
          url:      request.url(),
          address:  request.ip(),
          agent:    request.user_agent(),
          referer:  request.referer(),
        }

        puts("@[#{@table}] #{log.to_json}")
      end
  end
end
