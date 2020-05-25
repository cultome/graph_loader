require_relative 'lib/graph_loader/version'

Gem::Specification.new do |spec|
  spec.name          = "graph_loader"
  spec.version       = GraphLoader::VERSION
  spec.authors       = ["Carlos Soria"]
  spec.email         = ["csoria@cultome.io"]

  spec.summary       = %q{Neo4j importer}
  spec.description   = %q{Neo4j importer}
  spec.homepage      = "https://github.com/cultome/graph_loader"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/cultome/graph_loader"
  spec.metadata["changelog_uri"] = "https://github.com/cultome/graph_loader"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
