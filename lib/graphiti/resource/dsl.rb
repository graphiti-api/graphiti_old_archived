module Graphiti
  class Resource
    module DSL
      extend ActiveSupport::Concern

      class_methods do
        def filter(name, *args, &blk)
          opts = args.extract_options!
          type_override = args[0]

          if att = get_attr(name, :filterable, raise_error: :only_unsupported)
            aliases = [name, opts[:aliases]].flatten.compact
            operators = FilterOperators.build(self, att[:type], opts, &blk)

            if Graphiti::Types[att[:type]][:canonical_name] == :boolean
              opts[:single] = true
            end

            required = att[:filterable] == :required || !!opts[:required]
            config[:filters][name.to_sym] = {
              aliases: aliases,
              name: name.to_sym,
              type: type_override || att[:type],
              allow: opts[:allow],
              deny: opts[:deny],
              single: !!opts[:single],
              dependencies: opts[:dependent],
              required: required,
              operators: operators.to_hash
            }
          else
            if type = args[0]
              attribute name, type, only: [:filterable]
              filter(name, opts, &blk)
            else
              raise Errors::ImplicitFilterTypeMissing.new(self, name)
            end
          end
        end

        def sort_all(&blk)
          if block_given?
            config[:_sort_all] = blk
          else
            config[:_sort_all]
          end
        end

        def sort(name, *args, &blk)
          opts = args.extract_options!

          if get_attr(name, :sortable, raise_error: :only_unsupported)
            config[:sorts][name] = {
              proc: blk
            }.merge(opts.slice(:only))
          else
            if type = args[0]
              attribute name, type, only: [:sortable]
              sort(name, opts, &blk)
            else
              raise Errors::ImplicitSortTypeMissing.new(self, name)
            end
          end
        end

        def paginate(&blk)
          config[:pagination] = blk
        end

        def stat(symbol_or_hash, &blk)
          dsl = Stats::DSL.new(new.adapter, symbol_or_hash)
          dsl.instance_eval(&blk) if blk
          config[:stats][dsl.name] = dsl
        end

        def default_filter(name = nil, &blk)
          name ||= :__default
          config[:default_filters][name.to_sym] = {
            filter: blk
          }
        end

        def before_commit(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:before_commit][verb] = blk
          end
        end

        def on_rollback(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:on_rollback][verb] = blk
          end
        end

        def attribute(name, type, options = {}, &blk)
          raise Errors::TypeNotFound.new(self, name, type) unless Types[type]
          attribute_option(options, :readable)
          attribute_option(options, :writable)
          attribute_option(options, :sortable)
          attribute_option(options, :filterable)
          options[:type] = type
          options[:proc] = blk
          config[:attributes][name] = options
          apply_attributes_to_serializer
          options[:filterable] ? filter(name) : config[:filters].delete(name)
          options[:sortable] ? sort(name) : config[:sorts].delete(name)
        end

        def extra_attribute(name, type, options = {}, &blk)
          raise Errors::TypeNotFound.new(self, name, type) unless Types[type]
          defaults = {
            type: type,
            proc: blk,
            readable: true,
            writable: false,
            sortable: false,
            filterable: false
          }
          options = defaults.merge(options)
          config[:extra_attributes][name] = options
          apply_extra_attributes_to_serializer
        end

        def on_extra_attribute(name, &blk)
          if config[:extra_attributes][name]
            config[:extra_attributes][name][:hook] = blk
          else
            raise Errors::ExtraAttributeNotFound.new(self, name)
          end
        end

        def all_attributes
          attributes.merge(extra_attributes)
        end

        def apply_attributes_to_serializer
          serializer.type(type)
          Util::SerializerAttributes.new(self, attributes).apply
        end
        private :apply_attributes_to_serializer

        def apply_extra_attributes_to_serializer
          Util::SerializerAttributes.new(self, extra_attributes, true).apply
        end

        def attribute_option(options, name)
          if options[name] != false
            default = if only = options[:only]
                        Array(only).include?(name) ? true : false
                      elsif except = options[:except]
                        Array(except).include?(name) ? false : true
                      else
                        send(:"attributes_#{name}_by_default")
                      end
            options[name] ||= default
          end
        end
        private :attribute_option

       def relationship_option(options, name)
          if options[name] != false
            options[name] ||= send(:"relationships_#{name}_by_default")
          end
        end
        private :attribute_option
      end
    end
  end
end
