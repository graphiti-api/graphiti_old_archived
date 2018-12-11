require 'spec_helper'

RSpec.configure do |rspec|
  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec.shared_context "pagination_context", shared_context: :metadata do
  let(:proxy)      { double(resource: resource, query: query, scope: scope) }
  let(:resource)   { double(endpoint: endpoint) }
  let(:query)      { double(hash: params) }
  let(:scope)      { double(object: collection, pagination: double(size: current_per_page)) }
  let(:collection) do
    double(total_pages: total_pages,
           prev_page: prev_page,
           next_page: next_page,
           current_per_page: current_per_page)
  end
  let(:total_pages) { 3 }
  let(:prev_page){ 1 }
  let(:next_page){ 3 }
  let(:current_per_page){ 200 }
  let(:current_page){ 2 }
  let(:params) do
    {
      filter: {
        deprecated: "1"
      },
      page: {
        number: current_page,
        size: current_per_page
      }
    }
  end
  let(:endpoint) do
    {
      path: "/foos",
      full_path: "/api/v2/foos",
      url: "http://localhost:3000/api/v2/foos",
      actions: [:index, :show, :create, :update, :destroy]
    }
  end
  let(:kaminari_backend){ Graphiti::PaginationLinks::KaminariBackend.new(proxy) }
end

RSpec.configure do |rspec|
  rspec.include_context "pagination_context", include_shared: true
end
