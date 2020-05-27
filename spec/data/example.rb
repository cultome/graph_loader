entity :staff do
  page "staff"
  id column(0)
  label fixed("Staff"), (column(2) { |value|
    value == "director" ? "MovieDirector" : "ExecutiveProducer"
  })

  properties do
    name column(1)
  end
end

entity :movie do
  page "movie"
  id column(0)
  label "Movie"

  properties do
    name column(1)
    year column(2)
  end
end

entity :actor do
  page "actor"
  id column(0)
  label fixed("Actor")

  properties do
    name column(1)
    birthday column(2, type: :date)
  end
end

relationship do
  only_if(column(0)) { |col1| col1 == 1 }

  page "conections"
  label column(5)

  name column(5)
  from_id column(1)
  from_type column(2)
  to_id column(3)
  to_type column(4)

  properties do
    film_took column(6)
    cast_in column(7)
    year column(8)
    meet_in column(9)
  end
end

relationship do
  only_if(column(0), column(1)) { |type, id| type == 2 && id.start_with?("uuid") }

  page "conections"
  label "Custom"

  name column(5)
  from_find column(1)
  to_id column(3)
  to_type column(4)

  properties do
    year column(8)
  end
end

relationship do
  only_if(column(0)) { |type, id| type == 3 }

  page "conections"
  label column(5)

  name column(5)
  from_id column(1)
  from_type column(2)
  to_find column(3)

  properties do
    year column(8)
  end
end
