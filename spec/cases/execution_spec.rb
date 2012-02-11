require 'spec_helper'

describe MongoScript::Execution do
  before :each do
    MongoScript::Execution.script_dir = SCRIPTS_PATH
  end

  it "has a constant for LOADED_SCRIPTS" do
    MongoScript::Execution::LOADED_SCRIPTS.should be_a(Hash)
  end

  it "defines ScriptNotFound error" do
    MongoScript::Execution::ScriptNotFound.superclass.should == Errno::ENOENT
  end

  it "has a script_dir accessor" do
    stubby = stub("dir")
    MongoScript::Execution.script_dir = stubby
    MongoScript::Execution.script_dir.should == stubby
  end

  describe "#code_for" do
    before :all do
      @script_code = File.open(File.join(SCRIPTS_PATH, "sample_script.js")).read
    end

    it "loads and returns the code for a given file" do
      MongoScript::Execution.code_for("sample_script").should == @script_code
    end

    it "loads and returns the code for a given file by symbol" do
      MongoScript::Execution.code_for(:sample_script).should == @script_code
    end

    it "stores the value in LOADED_SCRIPTS" do
      MongoScript::Execution.code_for(:sample_script)
      MongoScript::Execution::LOADED_SCRIPTS["sample_script"].should == @script_code
    end

    it "raises a ScriptNotFound error if the file doesn't exist" do
      expect { MongoScript::Execution.code_for("i don't exist") }.to raise_exception(MongoScript::Execution::ScriptNotFound)
    end

    it "will look in another directory if provided" do
      my_path = "/foo/bar"
      my_script = "foo"
      File.stubs(:exists?).returns(true)
      stubby = stub("script contents")
      File.expects(:read).with(File.join(my_path, "#{my_script}.js")).returns(stubby)
      MongoScript::Execution.code_for(my_script, my_path).should == stubby
    end

    it "raises a NoScriptDirectory error if no directory is provided" do
      expect { MongoScript::Execution.code_for("sample_script", nil) }.to raise_exception(MongoScript::Execution::NoScriptDirectory)
    end
  end

  pending "sends the eval command through Mongo::Config.database" do
    code = stub("code")
    args = stub("args")
    Mongo::Config.database
  end
end