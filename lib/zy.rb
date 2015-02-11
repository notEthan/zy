proc { |p| $:.unshift(p) unless $:.any? { |lp| File.expand_path(lp) == p } }.call(File.expand_path(File.dirname(__FILE__)))

require 'zy/version'

require 'ffi-rzmq'
require 'json'

module Zy
  module Protocol
    NAME = 'zy'.freeze
    VERSION = '0.0'.freeze
    FORMAT = 'json'.freeze

    PARTS = [NAME, VERSION, FORMAT].freeze
    STRING = PARTS.join(' ').freeze
  end

  class Error < StandardError
  end

  class << self
    def zmq_context
      @zmq_context ||= ZMQ::Context.new
    end

    def zmq_context=(zmq_context)
      if @zmq_context
        raise Zy::Error, "zmq_context is already set"
      else
        @zmq_context = zmq_context
      end
    end
  end

  autoload :Server, 'zy/server'
  autoload :Request, 'zy/request'
  autoload :Reply, 'zy/reply'
  autoload :Natra, 'zy/natra'
  autoload :Middleware, 'zy/middleware'
  autoload :Logger, 'zy/logger'
end
