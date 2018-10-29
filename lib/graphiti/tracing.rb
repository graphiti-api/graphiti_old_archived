require 'opentracing'

module Graphiti
  class Tracer
    def start_active_span(operation_name, *args)
      operation_name = "graphiti.#{operation_name}"

      if block_given?
        tracing.start_active_span(operation_name, *args) do |scope|
          apply_tags(scope.span, standard_tags)

          yield scope
        end
      else
        tracing.start_active_span(operation_name, *args).tap do |scope|
          apply_tags(scope.span, standard_tags)
        end
      end
    end

    def trace(operation_name, context = nil)
      ret_val = nil

      start_active_span(operation_name) do |scope|
        Graphiti.broadcast(operation_name, context) do
          ret_val = yield scope
        end
      end

      ret_val
    end

    def apply_tags(span, tags)
      tags.compact.as_json.each_pair do |k,v|
        span.set_tag(k,v)
      end
    end

    private
    def tracing
      OpenTracing
    end

    def standard_tags
      {}
    end
  end
end