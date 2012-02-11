require 'spec_helper'

describe MongoScript::Execution do
  module ObjectWithExecution
    include MongoScript::ORM::MongoidAdapter
    include MongoScript::Execution
  end

  before :each do
    ObjectWithExecution.script_dir = SCRIPTS_PATH
  end

  it "has a constant for LOADED_SCRIPTS" do
    MongoScript::Execution::LOADED_SCRIPTS.should be_a(Hash)
  end

  it "defines ScriptNotFound error < Errno::ENOENT" do
    MongoScript::Execution::ScriptNotFound.superclass.should == Errno::ENOENT
  end

  it "defines ExecutionFailure error < RuntimeError" do
    MongoScript::Execution::ExecutionFailure.superclass.should == RuntimeError
  end

  it "has a script_dir accessor" do
    stubby = stub("dir")
    ObjectWithExecution.script_dir = stubby
    ObjectWithExecution.script_dir.should == stubby
  end

  describe ".code_for" do
    before :all do
      @script_code = File.open(File.join(SCRIPTS_PATH, "sample_script.js")).read
    end

    it "loads and returns the code for a given file" do
      ObjectWithExecution.code_for("sample_script").should == @script_code
    end

    it "loads and returns the code for a given file by symbol" do
      ObjectWithExecution.code_for(:sample_script).should == @script_code
    end

    it "stores the value in LOADED_SCRIPTS" do
      ObjectWithExecution.code_for(:sample_script)
      ObjectWithExecution::LOADED_SCRIPTS["sample_script"].should == @script_code
    end

    it "raises a ScriptNotFound error if the file doesn't exist" do
      expect { ObjectWithExecution.code_for("i don't exist") }.to raise_exception(ObjectWithExecution::ScriptNotFound)
    end

    it "will look in another directory if provided" do
      my_path = "/foo/bar"
      my_script = "foo"
      File.stubs(:exists?).returns(true)
      stubby = stub("script contents")
      File.expects(:read).with(File.join(my_path, "#{my_script}.js")).returns(stubby)
      ObjectWithExecution.code_for(my_script, my_path).should == stubby
    end

    it "raises a NoScriptDirectory error if no directory is provided" do
      expect { ObjectWithExecution.code_for("sample_script", nil) }.to raise_exception(ObjectWithExecution::NoScriptDirectory)
    end
  end

  describe ".execute_readonly_routine" do
    it "gets and passes the appropriate code and arguments to be run in readonly mode" do
      args = [1, 2, {}]
      name = "scriptname"
      stubby = stub("code")
      ObjectWithExecution.expects(:code_for).with(name).returns(stubby)
      ObjectWithExecution.expects(:execute_readonly_code).with(stubby, *args)
      ObjectWithExecution.execute_readonly_routine(name, *args)
    end
  end

  describe ".execute_readwrite_routine" do
    it "gets and passes the appropriate code and arguments to be run in readwrite mode" do
      args = [1, 2, {}]
      name = "scriptname"
      stubby = stub("code")
      ObjectWithExecution.expects(:code_for).with(name).returns(stubby)
      ObjectWithExecution.expects(:execute_readwrite_code).with(stubby, *args)
      ObjectWithExecution.execute_readwrite_routine(name, *args)
    end
  end

  describe ".execute_readonly_code" do
    it "executes provided code and arguments in with nolock mode" do
      args = [1, 2, {}]
      code = stub("code")
      ObjectWithExecution.expects(:execute).with(code, args, {:nolock => true})
      ObjectWithExecution.execute_readonly_code(code, *args)
    end
  end

  describe ".execute_readwrite_code" do
    it "executes provided code and arguments with no Mongo options" do
      args = [1, 2, {}]
      code = stub("code")
      ObjectWithExecution.expects(:execute).with(code, args)
      ObjectWithExecution.execute_readwrite_code(code, *args)
    end
  end

  describe ".execute" do
    it "executes the command via the Mongo database" do
      MongoScript.database.expects(:command).returns({"ok" => 1.0})
      ObjectWithExecution.execute("code")
    end

    it "executes the code using the eval command" do
      code = stub("code")
      MongoScript.database.expects(:command).with(has_entries(:$eval => code)).returns({"ok" => 1.0})
      ObjectWithExecution.execute(code)
    end

    it "passes in any arguments provided" do
      args = [:a, :r, :g, :s]
      MongoScript.database.expects(:command).with(has_entries(:args => args)).returns({"ok" => 1.0})
      ObjectWithExecution.execute("code", args)
    end

    it "merges in any additional options" do
      options = {:a => stub("options")}
      MongoScript.database.expects(:command).with(has_entries(options)).returns({"ok" => 1.0})
      ObjectWithExecution.execute("code", [], options)
    end

    it "raises an ExecutionFailure error if the result[ok] != 1.0" do
      MongoScript.database.expects(:command).returns({"result" => {}})
      expect { ObjectWithExecution.execute("code") }.to raise_exception(MongoScript::Execution::ExecutionFailure)
    end

    it "returns the retval" do
      result = stub("result")
      MongoScript.database.expects(:command).returns({"ok" => 1.0, "retval" => result})
      ObjectWithExecution.execute("code").should == result
    end
  end
end