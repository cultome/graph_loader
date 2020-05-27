module GraphLoader::Readable
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
