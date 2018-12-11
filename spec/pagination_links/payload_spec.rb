require 'spec_helper'
require_relative "./pagination_context.rb"

RSpec.describe Graphiti::PaginationLinks::Payload do
  include_context "pagination_context"

  let(:instance) { described_class.new(proxy) }

  def pagination_link(number)
    uri = URI(endpoint[:url])
    uri.query = params.merge(page: { number: number, size: current_per_page }).to_query
    uri.to_s
  end

  describe '#generate' do
    before do
      allow(instance).to receive(:last_page).and_return(total_pages)
      allow(instance).to receive(:current_page).and_return(current_page)
      allow(instance).to receive(:page_size).and_return(current_per_page)
    end
    subject { instance.generate }
    let(:first_link){ subject[:first]}

    it 'generates a payload with the first, next, prev and last links' do
      expect(subject).to include(:first, :next, :last, :prev)
    end
    it 'generates a payload with links that contain current params' do
      expect(first_link).to eq pagination_link(1)
    end
  end

  describe "#pagination_link" do
    subject{ URI(instance.send(:pagination_link, current_page)) }
    it "retains existing params" do
      expect(subject.query).to eq(params.to_query)
    end
  end

  describe "#last_page" do
    subject{ instance.send(:last_page) }
    it "returns 1 page if item_count is 1 and page_size is 1" do
      allow(instance).to receive(:item_count).and_return(1)
      allow(instance).to receive(:page_size).and_return(1)
      expect(subject).to eq 1
    end

    it "returns 2 pages if item_count 3 and page_size is 2" do
      allow(instance).to receive(:item_count).and_return(3)
      allow(instance).to receive(:page_size).and_return(2)
      expect(subject).to eq 2
    end
  end
end
