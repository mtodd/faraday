require 'auth-hmac'

module Faraday
  class Request

    attr_accessor :sign_with

    # Sign the request with the specified `access_id` and `secret`.
    def sign!(access_id, secret)
      AuthHMAC.keys[access_id] = secret
      self.sign_with = access_id
    end

    # Include the `sign_with` property to ensure the request is signed with
    # the specified `access_id`.
    alias_method :original_to_env, :to_env
    def to_env(connection)
      original_to_env(connection).merge(:sign_with => self.sign_with)
    end

    class AuthHMAC < Faraday::Middleware
      AUTH_HEADER = "Authorization".freeze
      MD5_HEADER  = "Content-MD5".freeze

      # Modified CanonicalString to know how to pull from the Faraday-specific
      # env hash.
      class CanonicalString < ::AuthHMAC::CanonicalString
        def request_method(request)
          request[:method].to_s.upcase
        end
        def request_body(request)
          request[:body]
        end
        def request_path(request)
          URI.parse(request[:url]).path
        end
        def request_path(request, authenticate_referrer)
          return super if authenticate_referrer
          URI.parse(request[:url]).path
        end
        def headers(request)
          request[:request_headers]
        end
      end

      class << self
        attr_accessor :keys, :options
      end
      self.keys     = {}
      self.options  = {:service_id => "GitHubHMAC", :signature => CanonicalString}

      def self.auth
        ::AuthHMAC.new(keys, options)
      end
      def auth
        self.class.auth
      end

      def sign!(env, sign_with)
        self.auth.sign!(env, sign_with)

        # AuthHMAC doesn't set the headers in the `request_headers` hash.
        env[:request_headers][AUTH_HEADER]  = env.delete(AUTH_HEADER)
        env[:request_headers][MD5_HEADER]   = env.delete(MD5_HEADER)
      end

      def call(env)
        if sign_with = env.delete(:sign_with)
          sign!(env, sign_with)
        end

        @app.call(env)
      end

    end
  end
end
