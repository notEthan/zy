module Zy
  class Reply
    include Zy::Logger

    FIELDS = %w(status body).map(&:freeze).freeze

    class << self
      def from(reply_object, options = {})
        reply_object.is_a?(self) ? reply_object : new(reply_object, options)
      end
    end

    def initialize(object, options = {})
      @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)

      @object = object
      @on_complete = []
    end

    attr_reader :object

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
        error({'reply' => "could not generate JSON for #{@object.inspect}"})
        JSON.generate({'status' => ['error', 'server', 'internal_error']})
      end
    end

    FIELDS.each do |field|
      define_method(field) do
        @object[field]
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
