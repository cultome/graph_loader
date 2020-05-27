class GraphLoader::Scope::RelationshipScope < GraphLoader::Scope::BaseScope
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
