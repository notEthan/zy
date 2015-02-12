module Zy
  module Middleware
    class RequestLogger < Base
      COLORS = {
        :intense_green => "\e[92m",
        :intense_yellow => "\e[93m",
        :intense_red => "\e[91m",
        :intense_cyan => "\e[96m",
        :white => "\e[37m",
        :bold => "\e[1m",
        :reset => "\e[0m"
      }

      def initialize(app, logger, options = {})
        @logger = logger
        super(app, options)
      end

      def call(request)
        began_at = Time.now

        log_tags = Thread.current[:activesupport_tagged_logging_tags]
        log_tags = log_tags.dup if log_tags && log_tags.any?

        Reply.from(@app.call(request)).tap do |reply|
          reply.on_complete do
            log(request, reply, began_at, log_tags)
          end
        end
      end

      def log(request, reply, began_at, log_tags)
        now = Time.now

        status_color = begin
          if reply.success?
            :intense_green
          elsif reply.request_error?
            :intense_yellow
          elsif reply.server_error?
            :intense_red
          else
            :white
          end
        end

        status = reply.status.is_a?(Array) ? reply.status.join(' ') : '?'
        status_s = "#{COLORS[:bold]}#{COLORS[status_color]}#{status}#{COLORS[:reset]}"

        data = {
          'request_role' => 'server',
          'request_protocol' => request.protocol_string,
          'request' => request.object,
          'reply_protocol' => reply.protocol_string,
          'reply' => reply.object,
          'processing' => {
            'began_at' => began_at.utc.to_f,
            'duration' => now - began_at,
            'activesupport_tagged_logging_tags' => log_tags,
          }
        }
        json_data = JSON.dump(data)
        dolog = proc do
          now_s = now.strftime('%Y-%m-%d %H:%M:%S %Z')
          @logger.info "#{COLORS[:bold]}#{COLORS[:intense_cyan]}<#{COLORS[:reset]}" +
            " " +
            status_s +
            " : " +
            "#{COLORS[:bold]}#{COLORS[:intense_cyan]}#{request.action}#{COLORS[:reset]}" +
            " " +
            "#{COLORS[:intense_cyan]}#{request.resource}#{request.params ? (' ' + JSON.generate(request.params)) : ''}#{COLORS[:reset]}" +
            " @ " +
            "#{COLORS[:intense_cyan]}#{now_s}#{COLORS[:reset]}"
          @logger.info json_data
        end
        # do the logging with tags that applied to the request if appropriate 
        if @logger.respond_to?(:tagged) && log_tags
          @logger.tagged(log_tags, &dolog)
        else
          dolog.call
        end
      end
    end
  end
end
