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
      @reply_strings ||= ['zy 0.0 json', JSON.generate(@object)]
    end
  end
end
