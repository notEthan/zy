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
      server_socket = Zy.zmq_context.socket(ZMQ::REP)
      raise(ServerError, "failed to create socket") unless server_socket

      if @options['server_private_key']
        rc = server_socket.setsockopt(ZMQ::CURVE_SERVER, 1)
        raise(ServerError, "failed to set server socket to curve server") if rc < 0
        server_socket.setsockopt(ZMQ::CURVE_SECRETKEY, @options['server_private_key'])
        raise(ServerError, "failed to set server socket curve secret key") if rc < 0
      end

      if @options['bind']
        bind_rc = server_socket.bind(@options['bind'])
        raise(ServerError, "failed to bind server socket to #{@options['bind']}") if bind_rc < 0
      elsif @options['connect']
        connect_rc = server_socket.connect(@options['connect'])
        raise(ServerError, "failed to connect server socket to #{@options['connect']}") if connect_rc < 0
      else
        raise(ServerError, "must specify bind or connect address")
      end

      loop do
        request_s = ''
        recv_rc = server_socket.recv_string(request_s)
        raise(ServerError, "server socket failed to recv") if recv_rc < 0
        request = JSON.parse(request_s)
        reply = app.call(request)
        reply_s = JSON.generate(reply)
        send_rc = server_socket.send_string(reply_s)
        raise(ServerError, "server socket failed to send") if send_rc < 0
      end
    end
  end
end
