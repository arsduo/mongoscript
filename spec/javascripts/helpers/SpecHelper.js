// mock a Mongo DB
// if you're using IE < 9, you'll need to implement map
// but I doubt that will ever come up :)

var MockMongo = function(dbName) {
  var Collection = function(name, data) {
    return collection = {
      name: name,
      find: function(params, fields) {
        return new Query(params, fields, collection);
      },
      data: data || []
    }
  }

  var Query = function(params, fields, collection) {
    return {
      params: params,
      fields: fields,
      collection: collection,
      limit: function() {},
      sort: function() {},
      toArray: function() {
        // always return the collection's data
        return collection.data;
      }
    }
  }

  var prototype = {
    addCollection: function(name, data) {
      if (!this[name]) {
        this[name] = new Collection(name, data);

        // set up the system namespaces collection if it doesn't exist
        if (!this["system.namespaces"]) {
          this.addCollection("system.namespaces");
        }

        // and add the entry to the system.namespace array
        this["system.namespaces"].data.push({
          name: dbName + "." + name
        })
      }
    }
  }

  var db = Object.create(prototype);
  db.name = dbName;

  return db;
}

var db;

beforeEach(function() {
  db = MockMongo("mongoscript_test");
  db.addCollection("vehicles", [
    {car: 1},
    {truck: 2},
    {spaceship: 100000}
  ])

  db.addCollection("paths", [
    {road: 1},
    {rail: 2},
    {wormhole: 100000}
  ])
})

