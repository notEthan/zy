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
        raise(ServerError, "failed to set server socket to curve server (errno = #{ZMQ::Util.errno})") if rc < 0
        debug({:server_socket => {:curve => 'setting private key'}})
        rc = server_socket.setsockopt(ZMQ::CURVE_SECRETKEY, @options['server_private_key'])
        debug({:server_socket => {:curve => 'set private key'}})
        raise(ServerError, "failed to set server socket curve secret key (errno = #{ZMQ::Util.errno})") if rc < 0
      else
        debug({:server_socket => {:curve => 'private key not specified'}})
      end

      if @options['bind']
        debug({:server_socket => "binding #{@options['bind']}"})
        bind_rc = server_socket.bind(@options['bind'])
        debug({:server_socket => "bound #{@options['bind']}"})
        raise(ServerError, "failed to bind server socket to #{@options['bind']} (errno = #{ZMQ::Util.errno})") if bind_rc < 0
      elsif @options['connect']
        debug({:server_socket => "connecting #{@options['connect']}"})
        connect_rc = server_socket.connect(@options['connect'])
        debug({:server_socket => "connected #{@options['connect']}"})
        raise(ServerError, "failed to connect server socket to #{@options['connect']} (errno = #{ZMQ::Util.errno})") if connect_rc < 0
      else
        raise(ServerError, "must specify bind or connect address")
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
          request_message = ZMQ::Message.create || raise(ServerError, "failed to create message (errno = #{ZMQ::Util.errno})")
          recv_rc = server_socket.recvmsg(request_message)
          debug({:server_socket => "recvd (#{recv_rc})"})
          raise(ServerError, "server socket failed to recv (errno = #{ZMQ::Util.errno})") if recv_rc < 0
          request_strings << request_message.copy_out_string
          debug({:server_socket => "copied #{request_strings.last}"})
          request_message.close
          more = server_socket.more_parts?
        end
        request = Request.new(request_strings)
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
        reply = Reply.from(reply_obj)
        reply.reply_strings.each_with_index do |reply_s, i|
          flags = i < reply.reply_strings.size - 1 ? ZMQ::SNDMORE : 0
          debug({:server_socket => "sending #{reply_s} (flags=#{flags})"})
          send_rc = server_socket.send_string(reply_s, flags)
          debug({:server_socket => "sent (#{send_rc})"})
          raise(ServerError, "server socket failed to send (errno = #{ZMQ::Util.errno})") if send_rc < 0
        end
        reply.complete
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
