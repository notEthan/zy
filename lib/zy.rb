proc { |p| $:.unshift(p) unless $:.any? { |lp| File.expand_path(lp) == p } }.call(File.expand_path(File.dirname(__FILE__)))

require 'zy/version'

require 'ffi-rzmq'
require 'json'

module Zy
  class Error < StandardError
  end

  class << self
    def zmq_context
      @zmq_context ||= begin
        ZMQ::Context.new.tap do |zmq_context|
          trap("INT") do
            STDERR.puts "goodbye!"
            zmq_context.terminate
            STDERR.puts "ok exiting"
            exit 0
            STDERR.puts "done"
          end
        end
      end
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
end
