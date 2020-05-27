module GraphLoader::DataType
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
