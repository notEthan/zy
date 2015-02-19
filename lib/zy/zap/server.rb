module Zy
  module ZAP
    class Server
      include Zy::Logger

      class Error < Zy::Error
      end

      def initialize(options)
        @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)

        debug({:zap_server_socket => 'creating'})
        @zap_server_socket = Zy.zmq_context.socket(ZMQ::REP)
        raise(Zy::ZAP::Server::Error, "failed to create zap server socket") unless @zap_server_socket
        debug({:zap_server_socket => "binding #{ZAP::ENDPOINT}"})
        bind_rc = @zap_server_socket.bind(ZAP::ENDPOINT)
        debug({:zap_server_socket => "bound #{ZAP::ENDPOINT}"})
        raise(Zy::ZAP::Server::Error, "failed to bind zap server socket to #{ZAP::ENDPOINT} (errno = #{ZMQ::Util.errno})") if bind_rc < 0
      end

      def start
        # TODO maybe better to do this in the same loop as the server using poller?
        loop do
          debug({:zap_server_socket => "ready to recv"})
          request_strings = []
          more = true
          while more
            request_message = ZMQ::Message.create || raise(Zy::ZAP::Server::Error, "failed to create message (errno = #{ZMQ::Util.errno})")
            recv_rc = @zap_server_socket.recvmsg(request_message)
            debug({:zap_server_socket => "recvd (#{recv_rc})"})
            raise(Zy::ZAP::Server::Error, "zap server socket failed to recv (errno = #{ZMQ::Util.errno})") if recv_rc < 0
            request_strings << request_message.copy_out_string
            debug({:zap_server_socket => "copied #{request_strings.last.inspect}"})
            request_message.close
            more = @zap_server_socket.more_parts?
          end
          zap_request = ZAP::Request.create(request_strings)
          status = @options['zap_app'].call(zap_request)
          zap_reply = zap_request.reply(status)
          zap_reply.reply_strings.each_with_index do |reply_s, i|
            flags = i < zap_reply.reply_strings.size - 1 ? ZMQ::SNDMORE : 0
            debug({:zap_server_socket => "sending #{reply_s} (flags=#{flags})"})
            send_rc = @zap_server_socket.send_string(reply_s, flags)
            debug({:zap_server_socket => "sent (#{send_rc})"})
            raise(Zy::ZAP::Server::Error, "zap server socket failed to send (errno = #{ZMQ::Util.errno})") if send_rc < 0
          end
        end
      end
    end
  end
end
