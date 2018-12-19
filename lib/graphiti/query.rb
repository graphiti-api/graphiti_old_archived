module Graphiti
  class Query
    attr_reader :resource, :include_hash, :association_name, :params

    def initialize(resource, params, association_name = nil, nested_include = nil, parents = [])
      @resource = resource
      @association_name = association_name
      @params = params
      @params = @params.permit! if @params.respond_to?(:permit!)
      @params = @params.to_h if @params.respond_to?(:to_h)
      @params = @params.deep_symbolize_keys
      @include_param = nested_include || @params[:include]
      @parents = parents
    end

    def association?
      !!@association_name
    end

    def top_level?
      not association?
    end

    def links?
      return false if [:json, :xml, 'json', 'xml'].include?(params[:format])
      if Graphiti.config.links_on_demand
        [true, 'true'].include?(@params[:links])
      else
        true
      end
    end

    def pagination_links?
      return !!@params[:pagination_links]
    end

    def debug_requested?
      !!@params[:debug]
    end

    def hash
      @hash ||= {}.tap do |h|
        h[:filter] = filters unless filters.empty?
        h[:sort] = sorts unless sorts.empty?
        h[:page] = pagination unless pagination.empty?
        unless association?
          h[:fields] = fields unless fields.empty?
          h[:extra_fields] = extra_fields unless extra_fields.empty?
        end
        h[:stats] = stats unless stats.empty?
        h[:include] = sideload_hash unless sideload_hash.empty?
      end
    end

    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    def sideload_hash
      @sideload_hash = begin
        {}.tap do |hash|
          sideloads.each_pair do |key, value|
            hash[key] = sideloads[key].hash
          end
        end
      end
    end

    def sideloads
      @sideloads ||= begin
        {}.tap do |hash|
          include_hash.each_pair do |key, sub_hash|
            sideload = @resource.class.sideload(key)
            if sideload
              _parents = parents + [self]
              sub_hash = sub_hash[:include] if sub_hash.has_key?(:include)
              hash[key] = Query.new(sideload.resource, @params, key, sub_hash, _parents)
            else
              handle_missing_sideload(key)
            end
          end
        end
      end
    end

    def parents
      @parents ||= []
    end

    def fields
      @fields ||= begin
        hash = parse_fieldset(@params[:fields] || {})
        hash.each_pair do |type, fields|
          hash[type] += extra_fields[type] if extra_fields[type]
        end
        hash
      end
    end

    def extra_fields
      @extra_fields ||= parse_fieldset(@params[:extra_fields] || {})
    end

    def filters
      @filters ||= begin
        {}.tap do |hash|
          (@params[:filter] || {}).each_pair do |name, value|
            name = name.to_sym

            if legacy_nested?(name)
              filter_name = value.keys.first.to_sym
              filter_value = value.values.first
              if @resource.get_attr!(filter_name, :filterable, request: true)
                hash[filter_name] = filter_value
              end
            elsif nested?(name)
              name = name.to_s.split('.').last.to_sym
              validate!(name, :filterable)
              hash[name] = value
            elsif top_level? && validate!(name, :filterable)
              hash[name] = value
            end
          end
        end
      end
    end

    def sorts
      @sorts ||= begin
        return @params[:sort] if @params[:sort].is_a?(Array)
        return [] if @params[:sort].nil?

        [].tap do |arr|
          sort_hashes do |key, value, type|
            if legacy_nested?(type)
              @resource.get_attr!(key, :sortable, request: true)
              arr << { key => value }
            elsif !type && top_level? && validate!(key, :sortable)
              arr << { key => value }
            elsif nested?("#{type}.#{key}")
              arr << { key => value }
            end
          end
        end
      end
    end

    def pagination
      @pagination ||= begin
        {}.tap do |hash|
          (@params[:page] || {}).each_pair do |name, value|
            if legacy_nested?(name)
              value.each_pair do |k,v|
                hash[k.to_sym] = v.to_i
              end
            elsif nested?(name)
              hash[name.to_s.split('.').last.to_sym] = value
            elsif top_level? && [:number, :size].include?(name.to_sym)
              hash[name.to_sym] = value.to_i
            end
          end
        end
      end
    end

    def include_hash
      @include_hash ||= begin
        requested = include_directive.to_hash

        allowlist = nil
        if @resource.context && @resource.context.respond_to?(:sideload_allowlist)
          allowlist = @resource.context.sideload_allowlist
          allowlist = allowlist[@resource.context_namespace] if allowlist
        end

        allowlist ? Util::IncludeParams.scrub(requested, allowlist) : requested
      end

      @include_hash
    end

    def stats
      @stats ||= begin
        {}.tap do |hash|
          (@params[:stats] || {}).each_pair do |k, v|
            if legacy_nested?(k)
              raise NotImplementedError.new('Association statistics are not currently supported')
            elsif top_level?
              v = v.split(',') if v.is_a?(String)
              hash[k.to_sym] = Array(v).flatten.map(&:to_sym)
            end
          end
        end
      end
    end

    def paginate?
      not [false, 'false'].include?(@params[:paginate])
    end

    private

    # Try to find on this resource
    # If not there, follow the legacy logic of scalling all other
    # resource names/types
    # TODO: Eventually, remove the legacy logic
    def validate!(name, flag)
      return false if name.to_s.include?('.') # nested

      if att = @resource.get_attr(name, flag, request: true)
        return att
      else
        not_associated_name = !@resource.class.association_names.include?(name)
        not_associated_type = !@resource.class.association_types.include?(name)

        if not_associated_name && not_associated_type
          @resource.get_attr!(name, flag, request: true)
          return true
        end
        false
      end
    end

    def nested?(name)
      return false unless association?

      split = name.to_s.split('.')
      query_names = split[0..split.length-2].map(&:to_sym)
      my_names = parents.map(&:association_name).compact + [association_name].compact
      query_names == my_names
    end

    def legacy_nested?(name)
      association? &&
        (name == @resource.type || name == @association_name)
    end

    def parse_fieldset(fieldset)
      {}.tap do |hash|
        fieldset.each_pair do |type, fields|
          type       = type.to_sym
          fields     = fields.split(',') unless fields.is_a?(Array)
          hash[type] = fields.map(&:to_sym)
        end
      end
    end

    def include_directive
      @include_directive ||= JSONAPI::IncludeDirective.new(@include_param)
    end

    def handle_missing_sideload(name)
      if Graphiti.config.raise_on_missing_sideload
        raise Graphiti::Errors::InvalidInclude
          .new(@resource, name)
      end
    end

    def sort_hash(attr)
      value = attr[0] == '-' ? :desc : :asc
      key   = attr.sub('-', '').to_sym

      { key => value }
    end

    def sort_hashes
      sorts = @params[:sort].split(',')
      sorts.each do |s|
        attr = nil
        type = s
        if s.include?('.')
          split = s.split('.')
          attr = split.pop
          type = split.join('.')
        end

        if attr.nil? # top-level
          next if @association_name
          hash = sort_hash(type)
          yield hash.keys.first.to_sym, hash.values.first
        else
          if type[0] == '-'
            type = type.sub('-', '')
            attr = "-#{attr}"
          end
          hash = sort_hash(attr)
          yield hash.keys.first.to_sym, hash.values.first, type.to_sym
        end
      end
    end
  end
end
