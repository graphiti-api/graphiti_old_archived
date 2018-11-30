module Graphiti
  module Links
    class Payload
      attr_reader :proxy
      def initialize(proxy)
        @proxy   = proxy
      end

      def generate
        {  }.tap do |links|
          links[:first] = pagination_link(1)
          links[:last] = pagination_link(collection.total_pages)
          links[:prev] = pagination_link(collection.prev_page) if collection.prev_page
          links[:next] = pagination_link(collection.next_page) if collection.next_page
        end
      end

      private
      def collection
        @collection ||= proxy.scope.object
      end

      def page_size
        @page_size ||= collection.current_per_page
      end

      def pagination_link(page)
        uri = URI(proxy.resource.endpoint[:url].to_s)
        uri.query = {
          page: {
            number: page,
            size: page_size
          }
        }.to_query
        uri.to_s
      end
    end
  end
end
