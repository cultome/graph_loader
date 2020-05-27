class GraphLoader::Scope::RootScope < GraphLoader::Scope::BaseScope
  def initialize
    @entities = []
    @relationships = []
  end

  def entity(name, &block)
    entity = GraphLoader::Scope::EntityScope.new name
    entity.instance_eval(&block)

    @entities << entity
  end

  def relationship(name = nil, from: nil, to: nil, &block)
    relationship = GraphLoader::Scope::RelationshipScope.new name, from, to
    relationship.instance_eval(&block)

    @relationships << relationship
  end
end
