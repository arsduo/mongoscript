require 'spec_helper'

describe MongoScript::Execution do
  module ObjectWithExecution
    include MongoScript::ORM::MongoidAdapter
    include MongoScript::Execution
  end

  before :all do
    @original_script_dirs = ObjectWithExecution.script_dirs
  end

  before :each do
    ObjectWithExecution.script_dirs = @original_script_dirs
  end

  it "has a constant for LOADED_SCRIPTS" do
    MongoScript::Execution::LOADED_SCRIPTS.should be_a(Hash)
  end

  it "defines ScriptNotFound error" do
    MongoScript::Execution::ScriptNotFound.superclass.should == StandardError
  end

  it "defines ExecutionFailure error < RuntimeError" do
    MongoScript::Execution::ExecutionFailure.superclass.should == RuntimeError
  end

  it "has a script_dir accessor" do
    stubby = stub("dir")
    ObjectWithExecution.script_dirs = stubby
    ObjectWithExecution.script_dirs.should == stubby
  end

  it "defaults to the built-in scripts" do
    location_pieces = File.dirname(__FILE__).split("/")
    # strip out /spec/cases to get back to the root directory
    gem_path = location_pieces[0, location_pieces.length - 2].join("/")
    ObjectWithExecution.script_dirs.should == [File.join(gem_path, "lib", "mongoscript", "javascripts")]
  end

  describe ".code_for" do
    before :all do
      @script_code = File.open(File.join(SCRIPTS_PATH, "sample_script.js")).read
    end

    before :each do
      ObjectWithExecution.script_dirs = @original_script_dirs + [SCRIPTS_PATH]
    end

    it "loads and returns the code for a given file" do
      ObjectWithExecution.code_for("sample_script").should == @script_code
    end

    it "loads and returns the code for a given file by symbol" do
      ObjectWithExecution.code_for(:sample_script).should == @script_code
    end

    it "underscores the filename (since JS function names will be passed in too)" do
      ObjectWithExecution.code_for("sampleScript").should == @script_code
    end

    it "stores the value in LOADED_SCRIPTS" do
      ObjectWithExecution.code_for(:sample_script)
      ObjectWithExecution::LOADED_SCRIPTS["sample_script"].should == @script_code
    end

    it "raises a ScriptNotFound error if the file doesn't exist" do
      File.stubs(:exists?).returns(false)
      expect { ObjectWithExecution.code_for("i don't exist") }.to raise_exception(ObjectWithExecution::ScriptNotFound)
    end

    it "will look in all the directories provided" do
      dir = "/foo/bar"
      my_script = "a script"
      ObjectWithExecution.script_dirs << dir
      File.stubs(:exists?).returns(*(ObjectWithExecution.script_dirs.map {|f| f == dir}))

      # make sure that we try to load the script
      stubby = stub("file contents")
      File.expects(:read).with(File.join(dir, "#{my_script}.js")).returns(stubby)
      ObjectWithExecution.code_for(my_script).should == stubby
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