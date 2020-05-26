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
  page "conections"

  name column(4)
  from_id column(0)
  from_type column(1)
  to_id column(2)
  to_type column(3)

  label column(4)

  properties do
    film_took column(5)
    cast_in column(6)
    year column(7)
    meet_in column(8)
  end
end
