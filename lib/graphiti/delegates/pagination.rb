module Graphiti
  module Delegates
    class Pagination
      def initialize(proxy)
        @proxy = proxy
      end

      def links?
        @proxy.query.pagination_links?
      end

      def links
        @links ||= {  }.tap do |links|
          links[:first] = pagination_link(1)
          links[:last] = pagination_link(last_page)
          links[:prev] = pagination_link(current_page - 1) unless current_page == 1
          links[:next] = pagination_link(current_page + 1) unless current_page == last_page
        end.select{|k,v| !v.nil? }
      end

      private

      def pagination_link(page)
        uri = URI(@proxy.resource.endpoint[:url].to_s)
        # Overwrite the pagination query params with the desired page
        uri.query = @proxy.query.hash.merge({
                                             page: {
                                               number: page,
                                               size: page_size
                                             }
                                           }).to_query
        uri.to_s
      end

      def last_page
        return @last_page if @last_page
        @last_page = (item_count / page_size)
        @last_page += 1 if item_count % page_size > 0
        @last_page
      end

      def item_count
        @item_count ||= @proxy.resource.stat(:total, :count).call(@proxy.scope.unpaginated_object, :total)
      end

      def current_page
        @current_page ||= (page_param[:number] || 1).to_i
      end

      def page_size
        @page_size ||= (page_param[:size] ||
                        @proxy.resource.default_page_size ||
                        Graphiti::Scoping::Paginate::DEFAULT_PAGE_SIZE).to_i
      end

      def page_param
        @page_param ||= (@proxy.query.hash[:page] || {})
      end
    end
  end
end
