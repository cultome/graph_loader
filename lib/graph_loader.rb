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
    fetch(:properties).map { |k,v| "#{k}: #{v.to_json}"}.join(", ")
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

      def initialize(arg, default: nil)
        @arg = arg
        @default = default
      end
    end

    class ColumnValueResolver < ValueResolver
      def resolve(row)
        cell = row[@arg]

        return @default if cell.nil?

        cell.value
      end
    end

    class FixedValueResolver < ValueResolver
      def resolve(row)
        @arg
      end
    end

    def column(position, default: nil)
      ColumnValueResolver.new(position, default: default)
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

    def from_id(value)
      @from_id = wrap_value value
    end

    def to_id(value)
      @to_id = wrap_value value
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

    def relationship(name, from:, to:, &block)
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

      # cross entities
      relationships.each do |rel|
        rel[:from] = entities_dict.fetch(rel[:from_type]).fetch(rel[:from_id])
        rel[:to] = entities_dict.fetch(rel[:to_type]).fetch(rel[:to_id])
      end

      puts "CREATE"
      puts entities.map(&:to_cypher).concat(relationships.map(&:to_cypher)).join(",\n")
      puts ";"
    end
  end
end
