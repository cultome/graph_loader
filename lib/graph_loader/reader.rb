class GraphLoader::Reader
  def self.read(script_name, data_file)
    script = File.read script_name

    root = GraphLoader::Scope::RootScope.new
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
