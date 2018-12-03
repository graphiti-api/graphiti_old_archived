require 'spec_helper'

RSpec.describe Graphiti::ResourceProxy do
  let(:resource){ double(endpoint: {  }) }
  let(:scope){ double(object: nil) }
  let(:query){ double }
  let(:opts){ {  } }
  let(:instance){ described_class.new(resource, scope, query, opts) }
  describe "links" do
    let(:query){ double(:pagination_links? => true) }
    let(:links_payload){ spy("links_payload") }
    subject{ instance.links }
    it "generates pagination links" do
      expect(instance).to receive(:links_payload).and_return(links_payload)
      subject
      expect(links_payload).to have_received(:generate)
    end
  end
end
