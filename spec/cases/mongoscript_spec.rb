require 'spec_helper'

describe MongoScript do
  describe "modules" do
    it "includes Execution" do
      MongoScript.included_modules.should include(MongoScript::Execution)
    end

    it "includes whatever's determined by orm_adapter" do
      MongoScript.included_modules.should include(MongoScript.orm_adapter)
    end
  end

  describe ".orm_adapter" do
    it "returns the Mongoid adapter if Mongoid is defined" do
      Object.stubs(:const_defined?).with("Mongoid").returns(true)
      MongoScript.orm_adapter.should == MongoScript::ORM::MongoidAdapter
    end

    it "raises a NoORMError if no Mongo ORM is available" do
      Object.stubs(:const_defined?).with("Mongoid").returns(false)
      expect { MongoScript.orm_adapter }.to raise_exception(MongoScript::NoORMError)
    end
  end
end