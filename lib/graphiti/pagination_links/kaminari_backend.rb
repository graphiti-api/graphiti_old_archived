module Graphiti
  module PaginationLinks
    # Responsible for coming up with
    class KaminariBackend < Backend

      protected
      def first_page
        pagination_link(1)
      end

      def last_page
        pagination_link(collection.total_pages)
      end

      def prev_page
        pagination_link(collection.prev_page) if collection.prev_page
      end

      def next_page
        pagination_link(collection.next_page) if collection.next_page
      end

      private
      def page_size
        @page_size ||= collection.current_per_page
      end

      def pagination_link(page)
        uri = URI(proxy.resource.endpoint[:url].to_s)
        # Overwrite the pagination query params with the desired page
        uri.query = proxy.query.hash.merge({
                                             page: {
                                               number: page,
                                               size: page_size
                                             }
                                           }).to_query
        uri.to_s
      end
    end
  end
end
