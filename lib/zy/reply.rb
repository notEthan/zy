module Zy
  class Reply
    class << self
      def from(reply_object)
        reply_object.is_a?(self) ? reply_object : new(reply_object)
      end
    end

    def initialize(object)
      @object = object
    end

    def reply_strings
      @reply_strings ||= [protocol_string, reply_string]
    end

    def protocol_string
      'zy 0.0 json'
    end

    def reply_string
      begin
        JSON.generate(@object)
      rescue JSON::GeneratorError
        # TODO log debug
        JSON.generate({"status" => ["error", "server", "internal_error"]})
      end
    end
  end
end
