require 'json'

module Zy
  class Request
    def initialize(request_s)
      @request_s = request_s
      @error_status = catch(:error) do
        begin
          @object = JSON.parse(request_s)
        rescue JSON::ParserError
          throw(:error, ['error', 'request', 'not_json'])
        end

        throw(:error, ['error', 'request', 'not_object']) unless @object.is_a?(Hash)
      end
    end

    attr_reader :error_status
    attr_reader :object
  end
end
