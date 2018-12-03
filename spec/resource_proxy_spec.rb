require 'spec_helper'

RSpec.describe Graphiti::ResourceProxy do
  let(:resource){ double(endpoint: {  }) }
  let(:scope){ double(object: nil) }
  let(:query){ double }
  let(:opts){ {  } }
  let(:instance){ described_class.new(resource, scope, query, opts) }
  describe "links" do
    let(:query){ double(:pagination_links? => true) }
    subject{ instance.links }
    it "generates pagination links" do
      expect(instance).to receive(:links_payload)
      subject
    end
  end
end
