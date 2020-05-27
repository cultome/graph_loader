class Hash
  def to_cypher
    if fetch(:scope_type) == :entity
      "(#{scope_id}#{scope_label} {#{scope_props}})"
    elsif fetch(:scope_type) == :relationship
      "(#{fetch(:from).scope_id})-[#{scope_label} {#{scope_props}}]->(#{fetch(:to).scope_id})"
    else
      raise "Invalid scope type to convert to cypher"
    end
  end

  def scope_label
    label = fetch(:label, [])

    val = label.is_a?(Array) ? label.join(":") : label

    (val.nil? || val.empty?) ? "" : ":#{val}"
  end

  def scope_props
    fetch(:properties).map do |k,v|
      next if v.nil?

      val = if v.is_a? Date
              "date(#{v.to_json})"
            else
              v.to_json
            end

      "#{k}: #{val}"
    end.compact.join(", ")
  end

  def scope_id
    "#{fetch(:scope_name)}_#{fetch(:id)}"
  end
end
