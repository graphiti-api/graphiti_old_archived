module Graphiti
  module PaginationLinks
    class Payload
      attr_reader :proxy
      def initialize(proxy)
        @proxy   = proxy
      end

      def generate
        pagination_backend.generate
      end

      private
      def pagination_backend
        @pagination_backend ||= if defined?(Kaminari)
                                  KaminariBackend.new(proxy)
                                else
                                  raise "Only Kaminari is supported for pagination links"
                                end
      end
    end
  end
end
