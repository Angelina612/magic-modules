# Copyright 2017 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'api/object'
require 'google/string_utils'

module Api
  # Represents a property type
  class Type < Api::Object::Named
    # The list of properties (attr_reader) that can be overridden in
    # <provider>.yaml.
    module Fields
      include Api::Object::Named::Properties

      attr_reader :default_value
      attr_reader :description
      attr_reader :exclude

      # Add a deprecation message for a field that's been deprecated in the API
      # use the YAML chomping folding indicator (>-) if this is a multiline
      # string, as providers expect a single-line one w/o a newline.
      attr_reader :deprecation_message

      # Add a removed message for fields no longer supported in the API. This should
      # be used for fields supported in one version but have been removed from
      # a different version.
      attr_reader :removed_message

      attr_reader :output # If set value will not be sent to server on sync
      attr_reader :immutable # If set to true value is used only on creation

      # url_param_only will not send the field in the resource body and will
      # not attempt to read the field from the API response.
      # NOTE - this doesn't work for nested fields
      attr_reader :url_param_only
      attr_reader :required

      # [Additional query Parameters to append to GET calls.
      attr_reader :read_query_params
      attr_reader :update_verb
      attr_reader :update_url
      # Some updates only allow updating certain fields at once (generally each
      # top-level field can be updated one-at-a-time). If this is set, we group
      # fields to update by (verb, url, fingerprint, id) instead of just
      # (verb, url, fingerprint), to allow multiple fields to reuse the same
      # endpoints.
      attr_reader :update_id
      # THe fingerprint value required to update this field. Downstreams should
      # GET the resource and parse the fingerprint value while doing each update
      # call. This ensures we can supply the fingerprint to each distinct
      # request.
      attr_reader :fingerprint_name
      # If true, we will include the empty value in requests made including
      # this attribute (both creates and updates).  This rarely needs to be
      # set to true, and corresponds to both the "NullFields" and
      # "ForceSendFields" concepts in the autogenerated API clients.
      attr_reader :send_empty_value

      # [Optional] If true, empty nested objects are sent to / read from the
      # API instead of flattened to null.
      # The difference between this and send_empty_value is that send_empty_value
      # applies when the key of an object is empty; this applies when the values
      # are all nil / default. eg: "expiration: null" vs "expiration: {}"
      # In the case of Terraform, this occurs when a block in config has optional
      # values, and none of them are used. Terraform returns a nil instead of an
      # empty map[string]interface{} like we'd expect.
      attr_reader :allow_empty_object

      attr_reader :min_version
      attr_reader :exact_version

      # A list of properties that conflict with this property. Uses the "lineage"
      # field to identify the property eg: parent.meta.label.foo
      attr_reader :conflicts

      # A list of properties that at least one of must be set.
      attr_reader :at_least_one_of

      # A list of properties that exactly one of must be set.
      attr_reader :exactly_one_of

      # A list of properties that are required to be set together.
      attr_reader :required_with

      # Can only be overridden - we should never set this ourselves.
      attr_reader :new_type

      # A pattern that maps expected user input to expected API input.
      attr_reader :pattern

      # ====================
      # Terraform Overrides
      # ====================

      attr_reader :diff_suppress_func # Adds a DiffSuppressFunc to the schema
      attr_reader :state_func # Adds a StateFunc to the schema
      attr_reader :sensitive # Adds `Sensitive: true` to the schema
      # Does not set this value to the returned API value.  Useful for fields
      # like secrets where the returned API value is not helpful.
      attr_reader :ignore_read
      attr_reader :validation # Adds a ValidateFunc to the schema
      # Indicates that this is an Array that should have Set diff semantics.
      attr_reader :unordered_list

      attr_reader :is_set # Uses a Set instead of an Array
      # Optional function to determine the unique ID of an item in the set
      # If not specified, schema.HashString (when elements are string) or
      # schema.HashSchema are used.
      attr_reader :set_hash_func

      # if true, then we get the default value from the Google API if no value
      # is set in the terraform configuration for this field.
      # It translates to setting the field to Computed & Optional in the schema.
      attr_reader :default_from_api

      # https://github.com/hashicorp/terraform/pull/20837
      # Apply a ConfigMode of SchemaConfigModeAttr to the field.
      # This should be avoided for new fields, and only used with old ones.
      attr_reader :schema_config_mode_attr

      # Names of attributes that can't be set alongside this one
      attr_reader :conflicts_with

      # Names of fields that should be included in the updateMask.
      attr_reader :update_mask_fields

      # For a TypeMap, the expander function to call on the key.
      # Defaults to expandString.
      attr_reader :key_expander

      # For a TypeMap, the DSF to apply to the key.
      attr_reader :key_diff_suppress_func

      # ====================
      # Schema Modifications
      # ====================
      # Schema modifications change the schema of a resource in some
      # fundamental way. They're not very portable, and will be hard to
      # generate so we should limit their use. Generally, if you're not
      # converting existing Terraform resources, these shouldn't be used.
      #
      # With great power comes great responsibility.

      # Flattens a NestedObject by removing that field from the Terraform
      # schema but will preserve it in the JSON sent/retrieved from the API
      #
      # EX: a API schema where fields are nested (eg: `one.two.three`) and we
      # desire the properties of the deepest nested object (eg: `three`) to
      # become top level properties in the Terraform schema. By overriding
      # the properties `one` and `one.two` and setting flatten_object then
      # all the properties in `three` will be at the root of the TF schema.
      #
      # We need this for cases where a field inside a nested object has a
      # default, if we can't spend a breaking change to fix a misshapen
      # field, or if the UX is _much_ better otherwise.
      #
      # WARN: only fully flattened properties are currently supported. In the
      # example above you could not flatten `one.two` without also flattening
      # all of it's parents such as `one`
      attr_reader :flatten_object

      # ===========
      # Custom code
      # ===========
      # All custom code attributes are string-typed.  The string should
      # be the name of a template file which will be compiled in the
      # specified / described place.

      # A custom expander replaces the default expander for an attribute.
      # It is called as part of Create, and as part of Update if
      # object.input is false.  It can return an object of any type,
      # so the function header *is* part of the custom code template.
      # As with flatten, `property` and `prefix` are available.
      attr_reader :custom_expand

      # A custom flattener replaces the default flattener for an attribute.
      # It is called as part of Read.  It can return an object of any
      # type, and may sometimes need to return an object with non-interface{}
      # type so that the d.Set() call will succeed, so the function
      # header *is* a part of the custom code template.  To help with
      # creating the function header, `property` and `prefix` are available,
      # just as they are in the standard flattener template.
      attr_reader :custom_flatten
    end

    include Fields

    attr_reader :__resource
    attr_reader :__parent # is nil for top-level properties

    MAX_NAME = 20

    def validate
      super
      check :description, type: ::String, required: true
      check :exclude, type: :boolean, default: false, required: true
      check :deprecation_message, type: ::String
      check :removed_message, type: ::String
      check :min_version, type: ::String
      check :exact_version, type: ::String
      check :output, type: :boolean
      check :required, type: :boolean
      check :send_empty_value, type: :boolean
      check :allow_empty_object, type: :boolean
      check :url_param_only, type: :boolean
      check :read_query_params, type: ::String
      check :immutable, type: :boolean

      raise 'Property cannot be output and required at the same time.' \
        if @output && @required

      check :update_verb, type: Symbol, allowed: %i[POST PUT PATCH NONE],
                          default: @__resource&.update_verb

      check :update_url, type: ::String
      check :update_id, type: ::String
      check :fingerprint_name, type: ::String
      check :pattern, type: ::String

      check_default_value_property
      check_conflicts
      check_at_least_one_of
      check_exactly_one_of
      check_required_with

      check :sensitive, type: :boolean, default: false
      check :is_set, type: :boolean, default: false
      check :default_from_api, type: :boolean, default: false
      check :unordered_list, type: :boolean, default: false
      check :schema_config_mode_attr, type: :boolean, default: false

      # technically set as a default everywhere, but only maps will use this.
      check :key_expander, type: ::String, default: 'expandString'
      check :key_diff_suppress_func, type: ::String

      check :diff_suppress_func, type: ::String
      check :state_func, type: ::String
      check :validation, type: Provider::Terraform::Validation
      check :set_hash_func, type: ::String

      check :custom_flatten, type: ::String
      check :custom_expand, type: ::String

      raise "'default_value' and 'default_from_api' cannot be both set" \
        if @default_from_api && !@default_value.nil?
    end

    def to_s
      JSON.pretty_generate(self)
    end

    # Prints a dot notation path to where the field is nested within the parent
    # object. eg: parent.meta.label.foo
    # The only intended purpose is to allow better error messages. Some objects
    # and at some points in the build this doesn't output a valid output.
    def lineage
      return name&.underscore if __parent.nil?

      "#{__parent.lineage}.#{name&.underscore}"
    end

    def to_json(opts = nil)
      # ignore fields that will contain references to parent resources and
      # those which will be added later
      ignored_fields = %i[@resource @__parent @__resource @api_name @update_verb
                          @__name @name @properties]
      json_out = {}

      instance_variables.each do |v|
        if v == :@conflicts && instance_variable_get(v).empty?
          # ignore empty conflict arrays
        elsif v == :@at_least_one_of && instance_variable_get(v).empty?
          # ignore empty at_least_one_of arrays
        elsif v == :@exactly_one_of && instance_variable_get(v).empty?
          # ignore empty exactly_one_of arrays
        elsif v == :@required_with && instance_variable_get(v).empty?
          # ignore empty required_with arrays
        elsif instance_variable_get(v) == false || instance_variable_get(v).nil?
          # ignore false booleans as non-existence indicates falsey
        elsif !ignored_fields.include? v
          json_out[v] = instance_variable_get(v)
        end
      end

      # convert properties to a hash based on name for nested readability
      json_out.merge!(properties&.map { |p| [p.name, p] }.to_h) \
        if respond_to? 'properties'

      JSON.generate(json_out, opts)
    end

    def check_default_value_property
      return if @default_value.nil?

      case self
      when Api::Type::String
        clazz = ::String
      when Api::Type::Integer
        clazz = ::Integer
      when Api::Type::Double
        clazz = ::Float
      when Api::Type::Enum
        clazz = ::Symbol
      when Api::Type::Boolean
        clazz = :boolean
      when Api::Type::ResourceRef
        clazz = [::String, ::Hash]
      else
        raise "Update 'check_default_value_property' method to support " \
              "default value for type #{self.class}"
      end

      check :default_value, type: clazz
    end

    # Checks that all conflicting properties actually exist.
    # This currently just returns if empty, because we don't want to do the check, since
    # this list will have a full path for nested attributes.
    def check_conflicts
      check :conflicts, type: ::Array, default: [], item_type: ::String

      return if @conflicts.empty?
    end

    # Returns list of properties that are in conflict with this property.
    def conflicting
      return [] unless @__resource

      @conflicts
    end

    # Checks that all properties that needs at least one of their fields actually exist.
    # This currently just returns if empty, because we don't want to do the check, since
    # this list will have a full path for nested attributes.
    def check_at_least_one_of
      check :at_least_one_of, type: ::Array, default: [], item_type: ::String

      return if @at_least_one_of.empty?
    end

    # Returns list of properties that needs at least one of their fields set.
    def at_least_one_of_list
      return [] unless @__resource

      @at_least_one_of
    end

    # Checks that all properties that needs exactly one of their fields actually exist.
    # This currently just returns if empty, because we don't want to do the check, since
    # this list will have a full path for nested attributes.
    def check_exactly_one_of
      check :exactly_one_of, type: ::Array, default: [], item_type: ::String

      return if @exactly_one_of.empty?
    end

    # Returns list of properties that needs exactly one of their fields set.
    def exactly_one_of_list
      return [] unless @__resource

      @exactly_one_of
    end

    # Checks that all properties that needs required with their fields actually exist.
    # This currently just returns if empty, because we don't want to do the check, since
    # this list will have a full path for nested attributes.
    def check_required_with
      check :required_with, type: ::Array, default: [], item_type: ::String

      return if @required_with.empty?
    end

    # Returns list of properties that needs required with their fields set.
    def required_with_list
      return [] unless @__resource

      @required_with
    end

    def type
      self.class.name.split('::').last
    end

    def parent
      @__parent
    end

    def min_version
      if @min_version.nil?
        @__resource.min_version
      else
        @__resource.__product.version_obj(@min_version)
      end
    end

    def exact_version
      return nil if @exact_version.nil? || @exact_version.blank?

      @__resource.__product.version_obj(@exact_version)
    end

    def exclude_if_not_in_version!(version)
      @exclude ||= exact_version != version unless exact_version.nil?
      @exclude ||= version < min_version
    end

    # Overriding is_a? to enable class overrides.
    # Ruby does not let you natively change types, so this is the next best
    # thing.
    def is_a?(clazz)
      return Module.const_get(@new_type).new.is_a?(clazz) if @new_type

      super(clazz)
    end

    # Overriding class to enable class overrides.
    # Ruby does not let you natively change types, so this is the next best
    # thing.
    def class
      return Module.const_get(@new_type) if @new_type

      super
    end

    # Returns nested properties for this property.
    def nested_properties
      nil
    end

    def removed?
      !(@removed_message.nil? || @removed_message == '')
    end

    def deprecated?
      !(@deprecation_message.nil? || @deprecation_message == '')
    end

    private

    # A constant value to be provided as field
    class Constant < Type
      attr_reader :value

      def validate
        @description = "This is always #{value}."
        super
      end
    end

    # Represents a primitive (non-composite) type.
    class Primitive < Type
    end

    # Represents a boolean
    class Boolean < Primitive
    end

    # Represents an integer
    class Integer < Primitive
    end

    # Represents a double
    class Double < Primitive
    end

    # Represents a string
    class String < Primitive
      def initialize(name = nil)
        super()

        @name = name
      end

      PROJECT = Api::Type::String.new('project')
      NAME = Api::Type::String.new('name')
    end

    # Properties that are fetched externally
    class FetchedExternal < Type
      attr_writer :resource

      def validate
        @conflicts ||= []
        @at_least_one_of ||= []
        @exactly_one_of ||= []
        @required_with ||= []
      end

      def api_name
        name
      end
    end

    class Path < Primitive
    end

    # Represents a fingerprint.  A fingerprint is an output-only
    # field used for optimistic locking during updates.
    # They are fetched from the GCP response.
    class Fingerprint < FetchedExternal
      def validate
        super
        @output = true if @output.nil?
      end
    end

    # Represents a timestamp
    class Time < Primitive
    end

    # A base class to tag objects that are composed by other objects (arrays,
    # nested objects, etc)
    class Composite < Type
    end

    # Forwarding declaration to allow defining Array::NESTED_ARRAY_TYPE
    class NestedObject < Composite
    end

    # Forwarding declaration to allow defining Array::RREF_ARRAY_TYPE
    class ResourceRef < Type
    end

    # Represents an array, and stores its items' type
    class Array < Composite
      attr_reader :item_type
      attr_reader :min_size
      attr_reader :max_size

      def validate
        super
        if @item_type.is_a?(NestedObject) || @item_type.is_a?(ResourceRef)
          @item_type.set_variable(@name, :__name)
          @item_type.set_variable(@__resource, :__resource)
          @item_type.set_variable(self, :__parent)
        end
        check :item_type, type: [::String, NestedObject, ResourceRef, Enum], required: true

        unless @item_type.is_a?(NestedObject) || @item_type.is_a?(ResourceRef) \
            || @item_type.is_a?(Enum) || type?(@item_type)
          raise "Invalid type #{@item_type}"
        end

        check :min_size, type: ::Integer
        check :max_size, type: ::Integer
      end

      def property_class
        case @item_type
        when NestedObject, ResourceRef
          type = @item_type.property_class
        when Enum
          raise 'aaaa'
        else
          type = property_ns_prefix
          type << get_type(@item_type).new(@name).type
        end
        type[-1] = "#{type[-1].camelize(:upper)}Array"
        type
      end

      def exclude_if_not_in_version!(version)
        super
        @item_type.exclude_if_not_in_version!(version) \
          if @item_type.is_a? NestedObject
      end

      def nested_properties
        return @item_type.nested_properties.reject(&:exclude) \
          if @item_type.is_a?(Api::Type::NestedObject)

        super
      end

      def item_type_class
        return @item_type \
          if @item_type.instance_of?(Class)

        Object.const_get(@item_type)
      end
    end

    # Represents an enum, and store is valid values
    class Enum < Primitive
      attr_reader :values
      attr_reader :skip_docs_values

      def validate
        super
        check :values, type: ::Array, item_type: [Symbol, ::String, ::Integer], required: true
        check :skip_docs_values, type: :boolean
      end

      def merge(other)
        result = self.class.new
        instance_variables.each do |v|
          result.instance_variable_set(v, instance_variable_get(v))
        end

        other.instance_variables.each do |v|
          if other.instance_variable_get(v).instance_of?(Array)
            result.instance_variable_set(v, deep_merge(result.instance_variable_get(v),
                                                       other.instance_variable_get(v)))
          else
            result.instance_variable_set(v, other.instance_variable_get(v))
          end
        end

        result
      end
    end

    # Represents a 'selfLink' property, which returns the URI of the resource.
    class SelfLink < FetchedExternal
      EXPORT_KEY = 'selfLink'.freeze

      attr_reader :resource

      def name
        EXPORT_KEY
      end

      def out_name
        EXPORT_KEY.underscore
      end
    end

    # Represents a reference to another resource
    class ResourceRef < Type
      # The fields which can be overridden in provider.yaml.
      module Fields
        attr_reader :resource
        attr_reader :imports
      end
      include Fields

      def validate
        super
        @name = @resource if @name.nil?
        @description = "A reference to #{@resource} resource" \
          if @description.nil?

        return if @__resource.nil? || @__resource.exclude || @exclude

        check :resource, type: ::String, required: true
        check :imports, type: ::String, required: TrueClass

        # TODO: (camthornton) product reference may not exist yet
        return if @__resource.__product.nil?

        check_resource_ref_exists
        check_resource_ref_property_exists
      end

      def property
        props = resource_ref.all_user_properties
                            .select { |prop| prop.name == @imports }
        return props.first unless props.empty?
        raise "#{@imports} does not exist on #{@resource}" if props.empty?
      end

      def resource_ref
        product = @__resource.__product
        resources = product.objects.select { |obj| obj.name == @resource }
        raise "Unknown item type '#{@resource}'" if resources.empty?

        resources[0]
      end

      def property_class
        type = property_ns_prefix
        type << [@resource, @imports, 'Ref']
        type[-1] = type[-1].join('_').camelize(:upper)
        type
      end

      private

      def check_resource_ref_exists
        product = @__resource.__product
        resources = product.objects.select { |obj| obj.name == @resource }
        raise "Missing '#{@resource}'" if resources.empty?
      end

      def check_resource_ref_property_exists
        exported_props = resource_ref.all_user_properties
        exported_props << Api::Type::String.new('selfLink') \
          if resource_ref.has_self_link
        raise "'#{@imports}' does not exist on '#{@resource}'" \
          if exported_props.none? { |p| p.name == @imports }
      end
    end

    # An structured object composed of other objects.
    class NestedObject < Composite
      # A custom getter is used for :properties instead of `attr_reader`

      def validate
        @description = 'A nested object resource' if @description.nil?
        @name = @__name if @name.nil?
        super

        raise "Properties missing on #{name}" if @properties.nil?

        @properties.each do |p|
          p.set_variable(@__resource, :__resource)
          p.set_variable(self, :__parent)
        end
        check :properties, type: ::Array, item_type: Api::Type, required: true
      end

      def property_class
        type = property_ns_prefix
        type << [@__resource.name, @name]
        type[-1] = type[-1].join('_').camelize(:upper)
        type
      end

      # Returns all properties including the ones that are excluded
      # This is used for PropertyOverride validation
      def all_properties
        @properties
      end

      def properties
        raise "Field '#{lineage}' properties are nil!" if @properties.nil?

        @properties.reject(&:exclude)
      end

      def nested_properties
        properties
      end

      # Returns the list of top-level properties once any nested objects with
      # flatten_object set to true have been collapsed
      def root_properties
        properties.flat_map do |p|
          if p.flatten_object
            p.root_properties
          else
            p
          end
        end
      end

      def exclude_if_not_in_version!(version)
        super
        @properties.each { |p| p.exclude_if_not_in_version!(version) }
      end
    end

    # An array of string -> string key -> value pairs, such as labels.
    # While this is technically a map, it's split out because it's a much
    # simpler property to generate and means we can avoid conditional logic
    # in Map.
    class KeyValuePairs < Composite
    end

    # Map from string keys -> nested object entries
    class Map < Composite
      # The list of properties (attr_reader) that can be overridden in
      # <provider>.yaml.
      module Fields
        # The type definition of the contents of the map.
        attr_reader :value_type

        # While the API doesn't give keys an explicit name, we specify one
        # because in Terraform the key has to be a property of the object.
        #
        # The name of the key. Used in the Terraform schema as a field name.
        attr_reader :key_name

        # A description of the key's format. Used in Terraform to describe
        # the field in documentation.
        attr_reader :key_description
      end
      include Fields

      def validate
        super
        check :key_name, type: ::String, required: true
        check :key_description, type: ::String

        @value_type.set_variable(@name, :__name)
        @value_type.set_variable(@__resource, :__resource)
        @value_type.set_variable(self, :__parent)
        check :value_type, type: Api::Type::NestedObject, required: true
        raise "Invalid type #{@value_type}" unless type?(@value_type)
      end

      def nested_properties
        @value_type.nested_properties.reject(&:exclude)
      end
    end

    # Support for schema ValidateFunc functionality.
    class Validation < Object
      # Ensures the value matches this regex
      attr_reader :regex
      attr_reader :function

      def validate
        super

        check :regex, type: String
        check :function, type: String
      end
    end

    def type?(type)
      type.is_a?(Type) || !get_type(type).nil?
    end

    def get_type(type)
      Module.const_get(type)
    end

    def property_ns_prefix
      [
        'Google',
        @__resource.__product.name.camelize(:upper),
        'Property'
      ]
    end
  end
end