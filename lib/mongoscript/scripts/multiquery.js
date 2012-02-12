function multiquery(queries) {
  var results = {};

  queries.forEach(function(collection, query) {
    var base, modifiers = query.modifiers || [];
    try {
      base = db[collection].find(query.query, query.fields || null)
      // apply any number of modifiers, such as sort, limit, etc.
      modifiers.forEach(function(modifier, by) {
        base = base[modifier](by)
      })
      results[collection] = base;
    }
    catch(e) {
      results[collection] = {error: e};
    }
  })

  return results;
}