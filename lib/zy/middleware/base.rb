module Zy
  module Middleware
    class Base
      def initialize(app, options = {})
        @app = app
        @options = options
      end
    end
  end
end
