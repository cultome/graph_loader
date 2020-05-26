require "graph_loader/version"
require "securerandom"
require "rubyXL"
require "json"

class Hash
  def to_cypher
    if fetch(:scope_type) == :entity
      "(#{scope_id}:#{scope_label} {#{scope_props}})"
    elsif fetch(:scope_type) == :relationship
      "(#{fetch(:from).scope_id})-[:#{scope_label} {#{scope_props}}]->(#{fetch(:to).scope_id})"
    else
      raise "Invalid scope type to convert to cypher"
    end
  end

  def scope_label
    label = fetch(:label)

    label.is_a?(Array) ? label.join(":") : label
  end

  def scope_props
    fetch(:properties).map do |k,v|
      next if v.nil?

      val = if v.is_a? Date
              "date(#{v.to_json})"
            else
              v.to_json
            end

      "#{k}: #{val}"
    end.compact.join(", ")
  end

  def scope_id
    "#{fetch(:scope_name)}_#{fetch(:id)}"
  end
end

module GraphLoader
  module Resolvable
    def resolve(row)
      raise "implement #resolve in #{self.class.name}"
    end
  end

  module DataTypes
    class ValueResolver
      include GraphLoader::Resolvable

      def initialize(arg, **kwargs, &block)
        @arg = arg
        @kwargs = kwargs
        @block = block
      end
    end

    class ColumnValueResolver < ValueResolver
      def resolve(row)
        cell = row[@arg]

        cell_val = if cell.nil?
          @kwargs.fetch(:default, nil)
        else
          cell.value
        end

        if @kwargs.key? :type
          cell_val = cast_to(@kwargs[:type], cell_val)
        end

        return cell_val if @block.nil?

        @block.call cell_val
      end

      private

      def cast_to(type, value)
        case type
        when :date
          cast_to_date value
        else
          raise "Unable to cast value [#{value}] to type [#{type}]"
        end
      end

      def cast_to_date(value)
        if value.is_a? DateTime
          value.to_date
        else
          raise "Unable to cast value [#{value}] of type [#{value.class.name}] to date"
        end
      end
    end

    class FixedValueResolver < ValueResolver
      def resolve(row)
        @arg
      end
    end

    def column(position, **kwargs, &block)
      ColumnValueResolver.new(position, **kwargs, &block)
    end

    def fixed(value)
      FixedValueResolver.new(value)
    end
  end

  module Readable
    class ReadableWrapper
      def initialize(entity, row)
        @entity = entity
        @row = row
      end

      def method_missing(mtd, *args, &block)
        if @entity.instance_variable_defined? "@#{mtd}"
          value = @entity.instance_variable_get "@#{mtd}"

          if value.is_a? Array
            value.map { |val| resolve_value val, @row }
          else
            resolve_value value, @row
          end
        elsif @entity.instance_variable_defined? "@properties"
          value = @entity.instance_variable_get("@properties").instance_variable_get("@data").fetch(mtd, nil)
          resolve_value value, @row
        else
          raise "Invalid property read [#{mtd}]"
        end
      end

      def resolve_value(value, row)
        value.respond_to?(:resolve) ? value.resolve(row) : value
      end
    end

    def read(row)
      ReadableWrapper.new(self, row)
    end

    def consume(wb)
      is_headers_row = true
      page_id = @page.resolve(nil)

      if wb[page_id].nil?
        require "pry";binding.pry
      end

      wb[page_id].map do |row|
        if is_headers_row
          is_headers_row = false

          next
        end

        consume_format read(row)
      end.compact
    end

    def consume_format(entity)
      {
        id: entity.id,
        scope_name: entity.scope_name,
        scope_type: self.class.name.split("::").last.downcase.gsub("scope", "").to_sym,
        label: entity.label,
        properties: entity.properties,
      }
    end
  end

  module DSL
    def page(value)
      @page = wrap_value value
    end

    def label(*values)
      @label = wrap_value values
    end

    def id(value)
      @id = wrap_value value
    end

    def properties(&block)
      @properties = GraphLoader::PropertiesScope.new
      @properties.instance_eval(&block)
    end

    private

    def wrap_value(value)
      if value.is_a? Array
        wrap_array value
      else
        value.respond_to?(:resolve) ? value : fixed(value)
      end
    end

    def wrap_array(values)
      values.map { |val| val.respond_to?(:resolve) ? val : fixed(val) }
    end
  end

  class Scope
    include GraphLoader::DSL
    include GraphLoader::DataTypes
    include GraphLoader::Readable
    include GraphLoader::Resolvable

    def initialize(scope_name)
      @scope_name = scope_name
    end
  end

  class PropertiesScope < Scope
    def initialize
      @data = {}
    end

    def resolve(row)
      @data.each_with_object({}) do |(key, val), acc|
        acc[key] = val.resolve(row)
      end
    end

    def method_missing(mtd, *args, &block)
      @data[mtd] = args.first
    end
  end

  class EntityScope < Scope
  end

  class RelationshipScope < Scope
    def initialize(name, from_type, to_type)
      super(name)

      @from_type = from_type
      @to_type = to_type
    end

    def method_missing(mtd, *args, &block)
      return super unless %i[from_id from_type to_id to_type name].include? mtd

      instance_variable_set("@#{mtd}", wrap_value(args.first))
    end

    def consume_format(entity)
      res = super entity

      res[:from_id] = entity.from_id
      res[:from_type] = entity.from_type
      res[:to_id] = entity.to_id
      res[:to_type] = entity.to_type

      res
    end
  end

  class RootScope
    def initialize
      @entities = []
      @relationships = []
    end

    def entity(name, &block)
      entity = GraphLoader::EntityScope.new name
      entity.instance_eval(&block)

      @entities << entity
    end

    def relationship(name = nil, from: nil, to: nil, &block)
      relationship = GraphLoader::RelationshipScope.new name, from, to
      relationship.instance_eval(&block)

      @relationships << relationship
    end
  end

  class Reader
    def self.read(script_name, data_file)
      script = File.read script_name

      root = GraphLoader::RootScope.new
      root.instance_eval script

      workbook = RubyXL::Parser.parse data_file

      entities = root.instance_variable_get("@entities").flat_map do |entity|
        entity.consume workbook
      end

      relationships = root.instance_variable_get("@relationships").flat_map do |relationship|
        relationship.consume workbook
      end

      entities_dict = entities.each_with_object(Hash.new { |h,k| h[k] = {} }) do |entity, acc|
        acc[entity[:scope_name]][entity[:id]] = entity
      end

      # relate entities
      relationships.each do |rel|
        rel[:from] = entities_dict.fetch(rel[:from_type].to_sym).fetch(rel[:from_id])
        rel[:to] = entities_dict.fetch(rel[:to_type].to_sym).fetch(rel[:to_id])
      end

      print "\nCREATE\n  "
      puts entities.map(&:to_cypher).concat(relationships.map(&:to_cypher)).join(",\n  ")
      puts ";"
    end
  end
end
