module Zy
  class Server
    include Zy::Logger

    class Error < Zy::Error
    end

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
      # start up a ZAP server if specified
      if @options['zap_app']
        Thread.new do
          Thread.current.abort_on_exception = true
          zap_server = Zy::ZAP::Server.new(
            'logger' => logger,
            'zap_app' => @options['zap_app'],
          )
          zap_server.start
        end

        # this makes a blocking request to the ZAP server, preventing 
        # the app server from starting up before the ZAP server is up
        debug({:zap_client_socket => 'creating'})
        zap_client_socket = Zy.zmq_context.socket(ZMQ::REQ)
        debug({:zap_client_socket => 'created (ZMQ::REQ)'})
        raise(ZAP::Server::Error, "failed to create client socket") unless zap_client_socket

        debug({:zap_client_socket => "connecting #{ZAP::ENDPOINT}"})
        connect_rc = zap_client_socket.connect(ZAP::ENDPOINT)
        debug({:zap_client_socket => "connected #{ZAP::ENDPOINT}"})
        raise(Zy::Server::Error, "failed to connect ZAP client socket to #{ZAP::ENDPOINT} (errno = #{ZMQ::Util.errno})") if connect_rc < 0
        
        # send a fake sort of a ZAP request
        request_strings = [ZAP::VERSION, '0', '', '127.0.0.1', '', 'NULL']
        request_strings.each_with_index do |request_s, i|
          flags = i < request_strings.size - 1 ? ZMQ::SNDMORE : 0
          debug({:zap_client_socket => "sending #{request_s} (flags=#{flags})"})
          send_rc = zap_client_socket.send_string(request_s, flags)
          debug({:zap_client_socket => "sent (#{send_rc})"})
          raise(Zy::Server::Error, "ZAP client socket failed to send (errno = #{ZMQ::Util.errno})") if send_rc < 0
        end

        # read a reply - don't care about the contents, just want to know ZAP is responsive 
        reply_strings = []
        more = true
        while more
          reply_message = ZMQ::Message.create || raise(Zy::Server::Error, "failed to create message (errno = #{ZMQ::Util.errno})")
          recv_rc = zap_client_socket.recvmsg(reply_message)
          debug({:zap_client_socket => "recvd (#{recv_rc})"})
          raise(Zy::Server::Error, "zap client socket failed to recv (errno = #{ZMQ::Util.errno})") if recv_rc < 0
          reply_strings << reply_message.copy_out_string
          debug({:zap_client_socket => "copied #{reply_strings.last}"})
          reply_message.close
          more = zap_client_socket.more_parts?
        end
      end

      debug({:server_socket => 'creating'})
      server_socket = Zy.zmq_context.socket(ZMQ::REP)
      debug({:server_socket => 'created (ZMQ::REP)'})
      raise(Zy::Server::Error, "failed to create server socket") unless server_socket

      if @options['server_private_key']
        debug({:server_socket => {:curve => 'setting to server'}})
        rc = server_socket.setsockopt(ZMQ::CURVE_SERVER, 1)
        debug({:server_socket => {:curve => 'set to server'}})
        raise(Zy::Server::Error, "failed to set server socket to curve server (errno = #{ZMQ::Util.errno})") if rc < 0
        debug({:server_socket => {:curve => 'setting private key'}})
        rc = server_socket.setsockopt(ZMQ::CURVE_SECRETKEY, @options['server_private_key'])
        debug({:server_socket => {:curve => 'set private key'}})
        raise(Zy::Server::Error, "failed to set server socket curve secret key (errno = #{ZMQ::Util.errno})") if rc < 0
      else
        debug({:server_socket => {:curve => 'private key not specified'}})
      end

      if @options['bind']
        debug({:server_socket => "binding #{@options['bind']}"})
        bind_rc = server_socket.bind(@options['bind'])
        debug({:server_socket => "bound #{@options['bind']}"})
        raise(Zy::Server::Error, "failed to bind server socket to #{@options['bind']} (errno = #{ZMQ::Util.errno})") if bind_rc < 0
      elsif @options['connect']
        debug({:server_socket => "connecting #{@options['connect']}"})
        connect_rc = server_socket.connect(@options['connect'])
        debug({:server_socket => "connected #{@options['connect']}"})
        raise(Zy::Server::Error, "failed to connect server socket to #{@options['connect']} (errno = #{ZMQ::Util.errno})") if connect_rc < 0
      else
        raise(Zy::Server::Error, "must specify bind or connect address")
      end

      trap("INT") do
        STDERR.puts "goodbye!"
        exit 0
      end

      loop do
        debug({:server_socket => "ready to recv"})
        request_strings = []
        more = true
        while more
          request_message = ZMQ::Message.create || raise(Zy::Server::Error, "failed to create message (errno = #{ZMQ::Util.errno})")
          recv_rc = server_socket.recvmsg(request_message)
          debug({:server_socket => "recvd (#{recv_rc})"})
          raise(Zy::Server::Error, "server socket failed to recv (errno = #{ZMQ::Util.errno})") if recv_rc < 0
          request_strings << request_message.copy_out_string
          debug({:server_socket => "copied #{request_strings.last}"})
          request_message.close
          more = server_socket.more_parts?
        end
        request = Request.new(request_strings, 'logger' => logger)
        if request.error_status
          reply_obj = {'status' => request.error_status}
        else
          begin
            reply_obj = app.call(request)
          rescue Exception => e
            debug({exception: {class: e.class, message: e.message, backtrace: e.backtrace}})
            reply_obj = {'status' => ['error', 'server', 'internal_error']}
          end
        end
        reply = Reply.from(reply_obj, 'logger' => logger)
        reply.reply_strings.each_with_index do |reply_s, i|
          flags = i < reply.reply_strings.size - 1 ? ZMQ::SNDMORE : 0
          debug({:server_socket => "sending #{reply_s} (flags=#{flags})"})
          send_rc = server_socket.send_string(reply_s, flags)
          debug({:server_socket => "sent (#{send_rc})"})
          raise(Zy::Server::Error, "server socket failed to send (errno = #{ZMQ::Util.errno})") if send_rc < 0
        end
        reply.complete
      end
    end
  end
end
