require 'json'

module Zy
  class Request
    include Zy::Logger

    FIELDS = %w(body resource action params).map(&:freeze).freeze

    def initialize(request_strings, options = {})
      @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)

      @request_strings = request_strings
      unless request_strings.is_a?(Array) && request_strings.all? { |s| s.is_a?(String) }
        raise(ArgumentError, "request_strings must be an Array of Strings; got #{request_strings.inspect}")
      end
      @error_status = catch(:error) do
        # this should not happen; it's not possible to get a 0-frame message in zmq
        throw(:error, ['error', 'request', 'no_frames']) if @request_strings.size < 1

        @protocol_string = @request_strings[0]
        @protocol_parts = @protocol_string.strip.split(/ +/)

        # protocol part 0: protocol name (zy)
        part = 0
        if @protocol_parts.size <= part
          throw(:error, ['error', 'protocol', 'protocol_name_not_specified'])
        elsif @protocol_parts[part] != 'zy'
          throw(:error, ['error', 'protocol', 'protocol_not_supported'])
        end

        # protocol part 1: version
        part = 1
        if @protocol_parts.size <= part
          throw(:error, ['error', 'protocol', 'version_not_specified'])
        elsif @protocol_parts[part] != '0.0'
          throw(:error, ['error', 'protocol', 'version_not_supported'])
        end

        # protocol part 2: format
        part = 2
        if @protocol_parts.size <= part
          throw(:error, ['error', 'protocol', 'format_not_specified'])
        elsif @protocol_parts[part] != 'json'
          throw(:error, ['error', 'protocol', 'format_not_supported'])
        end

        # protocol part(s) we don't recognize
        part = 3
        if @protocol_parts.size > part
          throw(:error, ['error', 'protocol', 'too_many_parts'])
        end

        if @request_strings.size < 2
          throw(:error, ['error', 'request', 'request_not_specified'])
        end

        @request_string = @request_strings[1]

        if @request_strings.size > 2
          throw(:error, ['error', 'request', 'too_many_frames'])
        end

        begin
          @object = JSON.parse(@request_string)
        rescue JSON::ParserError
          throw(:error, ['error', 'request', 'not_in_specified_format'])
        end

        throw(:error, ['error', 'request', 'not_object']) unless @object.is_a?(Hash)
      end
    end

    attr_reader :error_status
    attr_reader :object
    attr_reader :protocol_string

    def [](key)
      @object[key]
    end

    FIELDS.map do |key|
      define_method(key) { self[key] }
    end
  end
end
