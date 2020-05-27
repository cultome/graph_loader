module GraphLoader::DSL
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
    @properties = GraphLoader::Scope::PropertiesScope.new
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
