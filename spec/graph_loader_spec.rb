RSpec.describe GraphLoader do
  it "process script" do
    GraphLoader::Reader.read "spec/data/reference.rb", "spec/data/datafile.xlsx"
  end
end
