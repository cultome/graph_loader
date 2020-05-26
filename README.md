# GraphLoader

Maps a XLSX file to entities and relationships using a ruby DSL, and generate cypher queries to insert them.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graph_loader'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install graph_loader

## Usage

The first thing is define a schema file that maps the XSLX file to entities and relationships.

Schema file looks like this:

```ruby
# define an entity named person
entity :person do
  # the data for this entity is in the first page of XSLX file
  page 0
  # an "internal id" will in the first column (assumes that the first row contains headers)
  id column(0)
  # defines 2 labels for this entity: a fixed/static value and the value found in
  # fouth column (zero-index based). If the value in this column in empty, use a default value.
  label fixed("Politico"), column(3, default: "MalPolitico")

  # properties will be values inside the node properties
  # in this example we have 2, name and last_name, and will be populated with the
  # columns 1 and 2 of the selected page
  properties do
    name column(1)
    last_name column(2)
  end
end

# you can define any number of entities
entity :secretariat do
  page fixed(1)
  id column(0)
  label fixed("GovernmentDependency"), fixed("Secretariat")

  properties do
    name column(1)
  end
end

# relationships are given by two entities and has direction.
relationship :HAS_POLITICAL_CHARGE, from: :person, to: :secretariat do
  # a page can be given by its position or name
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
```

To generate the queries execute:

```
$ ./exe/loader gen <schemafile_path> <datafile_path>
```

The output of the command can be redirected to a file, which can be loaded into the Neo4J web UI.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/graph_loader. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/graph_loader/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the GraphLoader project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/graph_loader/blob/master/CODE_OF_CONDUCT.md).
