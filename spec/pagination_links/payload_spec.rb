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
      # use the kaminari backend for testing
      expect(instance).to receive(:pagination_backend).and_return(kaminari_backend)
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

end
