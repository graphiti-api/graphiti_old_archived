module Graphiti
  module PaginationLinks
    # Pseudo abstract class that will raise NotImplementedError if
    # the child does not implement #generate.
    class Backend
      attr_reader :proxy, :collection
      def initialize(proxy)
        @proxy = proxy
        @collection = proxy.scope.object
      end

      def generate
        {  }.tap do |links|
          links[:first] = first_page
          links[:last] = last_page
          links[:prev] = prev_page
          links[:next] = next_page
        end.select{|k,v| !v.nil? }
      end

      protected
      def first_page
        raise NotImplementedError, "#{self.class} must implement #first_page"
      end

      def last_page
        raise NotImplementedError, "#{self.class} must implement #last_page"
      end

      def prev_page
        raise NotImplementedError, "#{self.class} must implement #prev_page"
      end

      def next_page
        raise NotImplementedError, "#{self.class} must implement #next_page"
      end
    end
  end
end
