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

    def trace(operation_name)
      ret_val = nil

      start_active_span(operation_name) do |scope|
        ret_val = yield scope
      end

      ret_val
    end

    def set_scope_tags(span, query_hash)
      tags = {
        'graphiti.filters' => query_hash[:filter],
        'graphiti.pagination' => query_hash[:page],
        'graphiti.sorting' => query_hash[:sort],
      }.compact.as_json
      apply_tags(span, tags)
    end

    private
    def tracing
      OpenTracing
    end

    def apply_tags(span, tags)
      tags.each_pair do |k,v|
        span.set_tag(k,v)
      end
    end

    def standard_tags
      {}
    end
  end
end