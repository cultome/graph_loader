RSpec.describe GraphLoader do
  it "process reference script" do
    GraphLoader::Reader.read "spec/data/reference.rb", "spec/data/datafile.xlsx"
  end

  it "process complex example" do
    GraphLoader::Reader.read "spec/data/example.rb", "spec/data/datafile2.xlsx"
  end
end
