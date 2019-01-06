module Graphiti
  module JsonapiSerializableExt
    # This library looks up a serializer based on the record's class name
    # This wouldn't work for us, since a model may be associated with
    # multiple resources.
    # Instead, this variable is assigned when the query is resolved
    # To ensure we always render with the *resource* serializer
    module RendererOverrides
      def _build(object, exposures, klass)
        resource = object.instance_variable_get(:@__graphiti_resource)

        if resource.present?
          klass = object.instance_variable_get(:@__graphiti_serializer)
          klass.new(exposures.merge(object: object, resource: resource))
        else
          super(object, exposures, klass)
        end
      end
    end

    # See above comment
    module RelationshipOverrides
      def data
        @_resources_block = proc do
          resources = yield

          if resources.nil? || Array(resources)[0].instance_variable_get(:@__graphiti_resource)
            graphiti_data(resources)
          else
            jsonapi_data(resources)
          end
        end
      end

      def graphiti_data(resources)
        if resources.nil?
          nil
        elsif resources.respond_to?(:to_ary)
          Array(resources).map do |obj|
            klass = obj.instance_variable_get(:@__graphiti_serializer)
            resource = obj.instance_variable_get(:@__graphiti_resource)
            klass.new(@_exposures.merge(object: obj, resource: resource))
          end
        else
          klass = resources.instance_variable_get(:@__graphiti_serializer)
          resource = resources.instance_variable_get(:@__graphiti_resource)
          klass.new(@_exposures.merge(object: resources, resource: resource))
        end
      end

      def jsonapi_data(resources)
        if resources.nil?
          nil
        elsif resources.respond_to?(:to_ary)
          Array(resources).map do |obj|
            @_class[obj.class.name.to_sym].new(@_exposures.merge(object: obj))
          end
        else
          @_class[resources.class.name.to_sym].new(@_exposures.merge(object: resources))
        end
      end
    end

    JSONAPI::Serializable::Relationship.send(:prepend, RelationshipOverrides)
    JSONAPI::Serializable::Renderer.send(:prepend, RendererOverrides)
  end
end
