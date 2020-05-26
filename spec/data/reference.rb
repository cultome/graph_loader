entity :person do
  page 0
  id column(0)
  label fixed("Politico"), column(3, default: "MalPolitico")

  properties do
    name column(1)
    last_name column(2)
  end
end

entity :secretariat do
  page fixed(1)
  id column(0)
  label fixed("GovernmentDependency"), fixed("Secretariat")

  properties do
    name column(1)
  end
end

relationship :HAS_POLITICAL_CHARGE, from: :person, to: :secretariat do
  page "Cargo Político"
  from_id column(0)
  to_id column(5)
  label fixed("PoliticalCharge")

  properties do
    name column(1)
    date_period column(3)
    political_party column(2)
  end
end
