module Zy
  module ZAP
    ByMechanism = {}

    # a ZAP request with either a null mechanism, or something unrecognized 
    class Request
      class << self
        def create(strings)
          klass = ByMechanism[strings[FIELDS.index('mechanism')]]
          klass.new(strings)
        end

        private
        def define_credential_readers
          self::CREDENTIAL_FIELDS.map { |field| define_method(field) { @credential_attributes[field] } }
        end
      end

      FIELDS = %w(version request_id domain address identity mechanism).map(&:freeze).freeze

      CREDENTIAL_FIELDS = [].freeze
      define_credential_readers

      ByMechanism.default = self
      ByMechanism.update('NULL'.freeze => self)

      def initialize(strings)
        field_strings = strings[0...FIELDS.size]
        credential_strings = strings[FIELDS.size...(FIELDS.size + self.class::CREDENTIAL_FIELDS.size)]
        @field_attributes = FIELDS.zip(field_strings).inject({}) { |h,(k,v)| h.update(k => v) }
        @credential_attributes = self.class::CREDENTIAL_FIELDS.zip(credential_strings).inject({}) { |h,(k,v)| h.update(k => v) }
      end

      FIELDS.map { |field| define_method(field) { @field_attributes[field] } }

      def [](key)
        key = key.is_a?(Symbol) ? key.to_s : key
        if @field_attributes.key?(key)
          @field_attributes[key]
        elsif @credential_attributes.key?(key)
          @credential_attributes[key]
        else
          nil
        end
      end

      STATUSES = [
        OK_STATUS = {
          'text'.freeze => 'OK'.freeze,
          'code'.freeze => '200'.freeze,
        }.freeze,
        UNAUTHORIZED_STATUS = {
          'text'.freeze => 'UNAUTHORIZED'.freeze,
          'code'.freeze => '400'.freeze,
        }.freeze,
        ERROR_STATUS = {
          'text'.freeze => 'ERROR'.freeze,
          'code'.freeze => '500'.freeze,
        }.freeze,
      ].freeze

      def reply(status)
        unless status.is_a?(Hash)
          status = status.to_s if status.is_a?(Symbol) || status.is_a?(Integer)
          status = status.upcase if status.is_a?(String)
          status = STATUSES.detect { |nstatus| nstatus['text'] == status || nstatus['code'] == status } || ERROR_STATUS
        end
        ZAP::Reply.new(
          'version' => ZAP::VERSION,
          'request_id' => request_id,
          'status_code' => status['code'],
          'status_text' => status['text'],
          'user_id' => status['user_id'],
          'metadata' => status['metadata'],
        )
      end
    end

    class PlainRequest < Request
      CREDENTIAL_FIELDS = %w(username password).map(&:freeze).freeze
      define_credential_readers

      ByMechanism.update('PLAIN'.freeze => self)
    end

    class CurveRequest < Request
      CREDENTIAL_FIELDS = %w(client_key).map(&:freeze).freeze
      define_credential_readers

      ByMechanism.update('CURVE'.freeze => self)

      # the Z85-encoded client key
      def client_key_85
        out = "\0" * (client_key.size * 5 / 4 + 1)
        LibZMQ.zmq_z85_encode out, client_key, client_key.size
      end
    end

    class GSSAPIRequest < Request
      CREDENTIAL_FIELDS = %w(principal).map(&:freeze).freeze
      define_credential_readers

      ByMechanism.update('GSSAPI'.freeze => self)
    end

    ByMechanism.freeze
  end
end
