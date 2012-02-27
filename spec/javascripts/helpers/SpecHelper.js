// mock a Mongo DB
// if you're using IE < 9, you'll need to implement map
// but I doubt that will ever come up :)

var MockMongo = function(dbName) {
  var Collection = function(name, data) {
    // we have to declare this as a local var
    // since we need to embed it into the find scope
    var collection = {
      name: name,
      find: function(params, fields) {
        this.findResult = this.findResult || new Query(params, fields, collection);
        return this.findResult;
      },
      data: data || []
    };
    return collection;
  }

  var Query = function(params, fields, collection) {
    return {
      params: params,
      fields: fields,
      collection: collection,
      limit: function() { this.limitArgs = arguments; return this; },
      sort: function() { this.sortArgs = arguments; return this; },
      toArray: function() {
        // always return the collection's data
        return collection.data;
      },
      map: function() {
        var data = this.toArray();
        return data.map.apply(data, arguments)
      }
    }
  }

  var prototype = {
    toString: function() {
      return this.name;
    },

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

