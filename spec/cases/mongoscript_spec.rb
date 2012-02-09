require 'spec_helper'

describe MongoScript do
  describe ".orm_adapter" do
    it "returns the Mongoid adapter if Mongoid is defined" do
      Object.stubs(:const_defined?).with("Mongoid").returns(true)
      MongoScript.orm_adapter.should == MongoScript::ORM::MongoidAdapter
    end

    it "raises a NoORMError if no Mongo ORM is available" do
      MongoScript.stubs(:const_defined?).with("Mongoid").returns(false)
      expect { MongoScript.orm_adapter }.to raise_exception(MongoScript::NoORMError)
    end
  end
end