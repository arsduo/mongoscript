var queries = {
  users: {
    selector: {email: /^alex/},
    fields: {name: 1, _id: 1},
    modifiers: {
      limit: 3,
      sort: {name: 1}
    }
  },
  workspaces: {
    selector: {privacy: 2},
    fields: {privacy: 1, _id: 1, _type: 1},
    modifiers: {
      limit: 2
    }
  }
}

function multiquery(queries) {
  var results = {}, collectionObject;

  for (var collection in queries) {
    var query = queries[collection], base, modifiers = query.modifiers || [];
    try {
      collectionObject = db[collection];
      if (collectionObject) {
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