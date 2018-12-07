require 'spec_helper'
require_relative "pagination_links/pagination_context.rb"

RSpec.describe Graphiti::ResourceProxy do
  # let(:resource){ double(endpoint: {  }) }
  # let(:scope){ double(object: nil) }
  # let(:query){ double }
  # let(:opts){ {  } }
  include_context "pagination_context"
  let(:instance){ described_class.new(resource, scope, query, {  }) }
  describe "pagination_links" do
    let(:query){ double(:pagination_links? => true) }
    let(:payload){ "LINKS" }
    let(:pagination_links_payload){ double(generate: payload) }
    subject{ instance.pagination_links }
    it "generates pagination links" do
      expect(instance).to receive(:pagination_links_payload).and_return(pagination_links_payload)
      expect(instance.pagination_links).to eq(payload)
    end
  end
end
