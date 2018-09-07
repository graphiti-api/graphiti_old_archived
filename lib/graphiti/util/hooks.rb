module Graphiti
  module Util
    class Hooks
      def self.record
        self.reset!
        begin
          yield.tap { run }
        ensure
          self.reset!
        end
      end

      def self._hooks
        Thread.current[:_graphiti_hooks] || self.reset!
      end
      private_class_method :_hooks

      def self.reset!
        Thread.current[:_graphiti_hooks] = {
          before_commit: [],
          rollback: [],
          post_process: [],
          staged_rollbacks: []
        }
      end

      # Because hooks will be added from the outer edges of
      # the graph, working inwards
      def self.add(before_commit, rollback)
        _hooks[:before_commit].unshift(before_commit)
        _hooks[:rollback].unshift(rollback)
      end

      def self.add_post_process(prc)
        _hooks[:post_process].unshift(prc)
      end

      def self.run
        begin
          _hooks[:before_commit].each_with_index do |before_commit, idx|
            result = before_commit.call
            rollback = _hooks[:rollback][idx]

            # Want to run rollbacks in reverse order from before_commit hooks
            _hooks[:staged_rollbacks].unshift(-> { rollback.call(result) })
          end
        rescue => e
          _hooks[:staged_rollbacks].each {|h| h.call }
          raise e
        end

        _hooks[:post_process].each {|h| h.call }
      end
    end
  end
end
