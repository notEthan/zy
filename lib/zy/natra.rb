module Zy
  class Natra
    def self.inherited(klass)
      klass.instance_variable_set(:@constraints, {})
      klass.instance_variable_set(:@handlers, [])
    end

    module HandlerContext
      def with_constraints(constraints, &block)
        # keys and values: symbols become strings
        constraints = constraints.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v.is_a?(Symbol) ? v.to_s : v} }.inject({}, &:update)
        begin
          original_constraints = @constraints
          @constraints = @constraints.merge(constraints)
          yield
        ensure
          @constraints = original_constraints
        end
      end

      def resource(name, &block)
        with_constraints(:resource => name, &block)
      end

      def action(name = nil, &block)
        if name
          with_constraints(:action => name) { action(&block) }
        else
          @handlers << [@constraints, block]
        end
      end
    end

    extend HandlerContext

    def self.call(request)
      _, handler = @handlers.detect do |(constraints, action_block)|
        constraints.all? do |key, value|
          request[key] == value
        end
      end

      if handler
        handler.call(request)
      else
        {'status' => ['error', 'request', 'unroutable']}
      end
    end
  end
end
