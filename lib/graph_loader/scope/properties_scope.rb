class GraphLoader::Scope::PropertiesScope < GraphLoader::Scope::BaseScope
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
