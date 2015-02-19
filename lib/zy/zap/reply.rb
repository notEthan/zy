module Zy
  module ZAP
    class Reply
      FIELDS = %w(version request_id status_code status_text user_id metadata).map(&:freeze).freeze

      def initialize(attributes)
        @attributes = attributes
      end

      def reply_strings
        FIELDS.map { |field| @attributes[field] || '' }
      end
    end
  end
end
