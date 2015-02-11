require 'logger'

module Zy
  module Logger
    def logger
      @logger ||= (@options.is_a?(Hash) && @options['logger']) || begin
        ::Logger.new(STDOUT)
      end
    end

    %w(debug info warn error fatal).map do |severity|
      define_method(severity) do |message|
        unless message.is_a?(String)
          message = begin
            JSON.generate(message)
          rescue JSON::GeneratorError
            message.inspect
          end
        end
        logger.send(severity, message)
      end
    end
  end
end
