module Zy
  class Reply
    class << self
      def from(reply_object)
        reply_object.is_a?(self) ? reply_object : new(reply_object)
      end
    end

    def initialize(object)
      @object = object
      @on_complete = []
    end

    def reply_strings
      @reply_strings ||= [protocol_string, reply_string]
    end

    def protocol_string
      Zy::Protocol::STRING
    end

    def reply_string
      begin
        JSON.generate(@object)
      rescue JSON::GeneratorError
        # TODO log debug
        JSON.generate({"status" => ["error", "server", "internal_error"]})
      end
    end

    def on_complete(&block)
      @on_complete << block
    end

    def complete
      @on_complete.map(&:call)
    end
  end
end
