require "mongoscript/orm/mongoid_adapter"
require "mongoscript/version"
require "mongoscript/execution"

module MongoScript
  class NoORMError < StandardError; end

  # Returns the MongoScript adapter module for
  # whichever Mongo ORM is loaded (Mongoid, MongoMapper).
  #
  # @note: currently only Mongoid is supported.
  #
  # @raises NoORMError if no ORM module can be detected.
  #
  # @returns MongoScript::ORM::Mongoid if Mongoid is detected
  def self.orm_adapter
    if const_defined? "Mongoid"
      MongoScript::ORM::MongoidAdapter
    else
      raise NoORMError, "Unable to locate Mongoid!"
    end
  end

  include orm_adapter
  include Execution
end