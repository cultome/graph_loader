module GraphLoader::Resolvable
  def resolve(row)
    raise "implement #resolve in #{self.class.name}"
  end
end
