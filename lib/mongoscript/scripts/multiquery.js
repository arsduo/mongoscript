var queries = {
  users: {
    query: {email: /^alex/},
    fields: {name: 1, _id: 1},
    modifiers: {
      limit: 3,
      sort: {name: 1}
    }
  },
  workspaces: {
    query: {privacy: 2},
    fields: {privacy: 1, _id: 1, _type: 1},
    modifiers: {
      limit: 2
    }
  }
}

function multiquery(queries) {
  var results = {};

  for (var collection in queries) {
    var query = queries[collection], base, modifiers = query.modifiers || [];
    try {
      base = db[collection].find(query.query, query.fields || null)
      // apply any number of modifiers, such as sort, limit, etc.
      for (var modifier in modifiers) {
        base = base[modifier](modifiers[modifier])
      }
      results[collection] = base.toArray();
    }
    catch(e) {
      results[collection] = {error: e};
    }
  }

  return results;
}