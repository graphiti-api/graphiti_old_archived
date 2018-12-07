require 'spec_helper'
require_relative "./pagination_context.rb"

RSpec.describe Graphiti::PaginationLinks::KaminariBackend do
  include_context "pagination_context"
  describe '#pagination_link' do
    subject { kaminari_backend.send(:pagination_link, 1) }
    let(:filter_query){ { filter: params[:filter] }.to_query }

    it 'should contain current params' do
      expect(subject).to include(filter_query)
    end
  end
end
