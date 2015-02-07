require 'json'

module Zy
  class Request
    def initialize(request_strings)
      @request_strings = request_strings
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

    def [](key)
      @object[key]
    end
  end
end
