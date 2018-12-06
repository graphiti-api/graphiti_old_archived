require 'spec_helper'

RSpec.describe Graphiti::PaginationLinks::Payload do
  let(:proxy)      { double(resource: resource, query: query, scope: scope) }
  let(:resource)   { double(endpoint: endpoint) }
  let(:query)      { double(hash: params) }
  let(:scope)      { double(object: collection) }
  let(:collection) { double(total_pages: total_pages,
                            prev_page: prev_page,
                            next_page: next_page,
                            current_per_page: current_per_page)
  }
  let(:total_pages) { 3 }
  let(:prev_page){ 1 }
  let(:next_page){ 3 }
  let(:current_per_page){ 200 }
  let(:current_page){ 2 }
  let(:params)     {
    {:filter=>{:deprecated=>"1"}, :page=>{:number=>current_page, :size=>current_per_page}}
  }
  let(:endpoint)   {
    {
      path: "/foos",
      full_path: "/api/v2/foos",
      url: "http://localhost:3000/api/v2/foos",
      actions: [:index, :show, :create, :update, :destroy]
    }
  }
  let(:instance) { described_class.new(proxy) }

  def pagination_link(number)
    uri = URI(endpoint[:url])
    uri.query = params.merge(page: { number: number, size: current_per_page }).to_query
    uri.to_s
  end

  describe '#generate' do
    subject { instance.generate }
    let(:first_link){ subject[:first]}

    it 'generates a payload with the first, next, prev and last links' do
      expect(subject).to include(:first, :next, :last, :prev)
    end
    it 'generates a payload with links that contain current params' do
      expect(first_link).to eq pagination_link(1)
    end
  end

  describe '#pagination_link' do
    subject { instance.send(:pagination_link, 1) }
    let(:filter_query){ { filter: params[:filter] }.to_query }

    it 'should contain current params' do
      expect(subject).to include(filter_query)
    end
  end
end
