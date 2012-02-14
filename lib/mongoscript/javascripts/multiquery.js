var queries = {
  users: {
    selector: {email: "alex@alexkoppel.com"},
    fields: {name: 1, _id: 1},
    modifiers: {
      limit: 3,
      sort: {name: 1}
    },
    collection: "users",
  },
  workspaces: {
    selector: {privacy: 2},
    fields: {privacy: 1, _id: 1, _type: 1},
    modifiers: {
      limit: 2
    },
    collection: "workspaces"
  },
  bogus: {
    selector: {privacy: 2},
    collection: "bogus"
  }
}

function multiquery(queries) {
  var results = {}, collectionObject;

  // extract all the collection names,
  // so we can return an error if one is provided that doesn't exist
  // since db[invalidName] returns a collection object
  // we could perhaps make this more optimized by building a hash,
  // but it shouldn't be a problem in most cases
  var collectionNames = db["system.namespaces"].find().map(function(ns) { return ns.name }),
      dbName = db.toString()

  for (var collection in queries) {
    var query = queries[collection], base,
        modifiers = query.modifiers || [],
        collection = query.collection;

    try {
      if (collectionNames.indexOf(dbName + "." + collection) !== -1) {
        base = db[collection].find(query.selector, query.fields || null)
        // apply any number of modifiers, such as sort, limit, etc.
        for (var modifier in modifiers) {
          base = base[modifier](modifiers[modifier])
        }
        results[collection] = base.toArray();
      }
      else {
        // if the collection doesn't exist, return an error
        // (rather than null -- the DB allows queries on non-existent collections)
        // doing this here saves us a database call in Ruby
        results[collection] = {error: "Unable to locate collection " + (collection ? collection.toString() : collection)}
      }
    }
    catch(e) {
      results[collection] = {error: e};
    }
  }

  return results;
}