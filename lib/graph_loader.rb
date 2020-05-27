require "graph_loader/version"
require "securerandom"
require "rubyXL"
require "json"

class Hash
  def to_cypher
    if fetch(:scope_type) == :entity
      "(#{scope_id}#{scope_label} {#{scope_props}})"
    elsif fetch(:scope_type) == :relationship
      "(#{fetch(:from).scope_id})-[#{scope_label} {#{scope_props}}]->(#{fetch(:to).scope_id})"
    else
      raise "Invalid scope type to convert to cypher"
    end
  end

  def scope_label
    label = fetch(:label, [])

    val = label.is_a?(Array) ? label.join(":") : label

    (val.nil? || val.empty?) ? "" : ":#{val}"
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

      def sheetid
        @row.worksheet.sheet_name
      end

      def rowid
        @row.cells.first.row + 1
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

        if @only_if.nil?
          consume_format read(row)
        else
          args = @only_if[:args].map { |arg| arg.resolve(row) }

          consume_format(read(row)) if @only_if[:block].call(*args)
        end
      end.compact
    end

    def consume_format(entity)
      {
        id: entity.id,
        scope_name: entity.scope_name,
        scope_type: self.class.name.split("::").last.downcase.gsub("scope", "").to_sym,
        rowid: entity.rowid,
        sheetid: entity.sheetid,
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

    def only_if(*values, &block)
      @only_if = {
        args: values.map { |val| wrap_value val },
        block: block,
      }
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
      return super unless %i[to_find from_find from_id from_type to_id to_type name].include? mtd

      instance_variable_set("@#{mtd}", wrap_value(args.first))
    end

    def consume_format(entity)
      res = super entity

      res[:to_find] = entity.to_find unless entity.to_find.nil?
      res[:from_find] = entity.from_find unless entity.from_find.nil?
      res[:from_id] = entity.from_id unless entity.from_id.nil?
      res[:from_type] = entity.from_type unless entity.from_type.nil?
      res[:to_id] = entity.to_id unless entity.to_id.nil?
      res[:to_type] = entity.to_type unless entity.to_type.nil?

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
      to_match = []
      relationships.each do |rel|
        unless rel.key?(:from_find) || %i[from_type from_id].all? { |k| rel.key? k }
          raise "from_type and from_id or from_find are needed to relate entities"
        end

        unless rel.key?(:to_find) || %i[to_type to_id].all? { |k| rel.key? k }
          raise "to_type and to_id or to_find are needed to relate entities"
        end

        if rel.key? :from_find
          found_from = {
            scope_type: :entity,
            scope_name: :found,
            id: (rand * 10_000).to_i,
            properties: {
              id: rel[:from_find]
            },
          }

          to_match << (rel[:from] = found_from)
        else
          rel[:from] = related_entity :from, rel, entities_dict
        end

        if rel.key? :to_find
          found_to = {
            scope_type: :entity,
            scope_name: :found,
            id: (rand * 10_000).to_i,
            properties: {
              id: rel[:to_find]
            },
          }

          to_match << (rel[:to] = found_to)
        else
          rel[:to] = related_entity :to, rel, entities_dict
        end
      end

      print "\nMATCH\n  "
      puts to_match.map(&:to_cypher).join(",\n  ")
      print "\nCREATE\n  "
      puts entities.map(&:to_cypher).concat(relationships.map(&:to_cypher)).join(",\n  ")
      puts ";"
    end

    private

    def self.related_entity(rel_side, rel, entities_dict)
      by_type = entities_dict.fetch(rel["#{rel_side}_type".to_sym].to_sym, nil)
      raise "Invalid type in [#{rel_side}_type] in [#{rel[:sheetid]}:#{rel[:rowid]}]" if by_type.nil?

      value = by_type.fetch(rel["#{rel_side}_id".to_sym], nil)
      raise "Invalid [id] in [#{rel_side}_id] in [#{rel[:sheetid]}:#{rel[:rowid]}]" if value.nil?

      value
    end
  end
end
