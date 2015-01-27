module Zy
  class ServerError < Error
  end

  class Server
    # options may include:
    #
    # - app
    # - bind
    # - connect
    # - server_private_key
    def initialize(options)
      # stringify symbol keys
      @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
    end

    def app
      @options['app']
    end

    def start
      debug({:server_socket => 'creating'})
      server_socket = Zy.zmq_context.socket(ZMQ::REP)
      debug({:server_socket => 'created (ZMQ::REP)'})
      raise(ServerError, "failed to create socket") unless server_socket

      if @options['server_private_key']
        debug({:server_socket => {:curve => 'setting to server'}})
        rc = server_socket.setsockopt(ZMQ::CURVE_SERVER, 1)
        debug({:server_socket => {:curve => 'set to server'}})
        raise(ServerError, "failed to set server socket to curve server") if rc < 0
        debug({:server_socket => {:curve => 'setting private key'}})
        server_socket.setsockopt(ZMQ::CURVE_SECRETKEY, @options['server_private_key'])
        debug({:server_socket => {:curve => 'set private key'}})
        raise(ServerError, "failed to set server socket curve secret key") if rc < 0
      else
        debug({:server_socket => {:curve => 'private key not specified'}})
      end

      if @options['bind']
        debug({:server_socket => "binding #{@options['bind']}"})
        bind_rc = server_socket.bind(@options['bind'])
        debug({:server_socket => "bound #{@options['bind']}"})
        raise(ServerError, "failed to bind server socket to #{@options['bind']}") if bind_rc < 0
      elsif @options['connect']
        debug({:server_socket => "connecting #{@options['connect']}"})
        connect_rc = server_socket.connect(@options['connect'])
        debug({:server_socket => "connected #{@options['connect']}"})
        raise(ServerError, "failed to connect server socket to #{@options['connect']}") if connect_rc < 0
      else
        raise(ServerError, "must specify bind or connect address")
      end

      loop do
        request_s = ''
        debug({:server_socket => "ready to recv"})
        recv_rc = server_socket.recv_string(request_s)
        debug({:server_socket => "recvd (#{recv_rc}) #{request_s}"})
        raise(ServerError, "server socket failed to recv") if recv_rc < 0
        request = Request.new(request_s)
        if request.error_status
          reply = {'status' => request.error_status}
        else
          reply = app.call(request)
        end
        reply_s = JSON.generate(reply)
        debug({:server_socket => "sending #{reply_s}"})
        send_rc = server_socket.send_string(reply_s)
        debug({:server_socket => "sent (#{send_rc})"})
        raise(ServerError, "server socket failed to send") if send_rc < 0
      end
    end

    def logger
      @logger ||= @options['logger'] || begin
        require 'logger'
        ::Logger.new(STDOUT)
      end
    end

    def debug(message)
      logger.debug JSON.generate message
    end
  end
end
