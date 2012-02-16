function multiquery(queries) {
  var results = {}, collectionObject;

  // extract all the collection names,
  // so we can return an error if one is provided that doesn't exist
  // since db[invalidName] returns a collection object
  // we could perhaps make this more optimized by building a hash,
  // but it shouldn't be a problem in most cases
  var collectionNames = db["system.namespaces"].find().map(function(ns) { return ns.name }),
      dbName = db.toString(),
      query, base, modifiers, collection;

  for (var queryName in queries) {
    try {
      query = queries[queryName];
      modifiers = query.modifiers || [];
      collection = query.collection;

      if (collectionNames.indexOf(dbName + "." + collection) !== -1) {
        base = db[collection].find(query.selector, query.fields || null)
        // apply any number of modifiers, such as sort, limit, etc.
        for (var modifier in modifiers) {
          base = base[modifier](modifiers[modifier])
        }
        results[queryName] = base.toArray();
      }
      else {
        // if the collection doesn't exist, return an error
        // (rather than null -- the DB allows queries on non-existent collections)
        // doing this here saves us a database call in Ruby
        results[queryName] = {error: "Unable to locate collection " + (collection ? collection.toString() : collection)}
      }
    }
    catch(e) {
      results[queryName] = {error: e};
    }
  }

  return results;
}