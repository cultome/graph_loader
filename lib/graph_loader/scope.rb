module GraphLoader::Scope
  class BaseScope
    include GraphLoader::DSL
    include GraphLoader::DataType
    include GraphLoader::Readable
    include GraphLoader::Resolvable

    def initialize(scope_name)
      @scope_name = scope_name
    end
  end
end

require "graph_loader/scope/properties_scope"
require "graph_loader/scope/entity_scope"
require "graph_loader/scope/properties_scope"
require "graph_loader/scope/relationship_scope"
require "graph_loader/scope/root_scope"
