describe("Built-in MongoScript functions", function() {
  var queries;

  beforeEach(function() {
    queries = {
      cars: {
        selector: {wheels: 4},
        fields: {name: 1, _id: 1},
        modifiers: {
          limit: 3,
          sort: {name: 1}
        },
        collection: "vehicles",
      },
      routes: {
        selector: {hyperspace: true},
        fields: {distance: 1, _id: 1, _type: 1},
        modifiers: {
          limit: 2
        },
        collection: "paths"
      }
    };
  })

  describe("multiquery", function() {
    it("calls find for each provided query (selector and fields)", function() {
      var query, details;
      for (query in queries) {
        spyOn(db[queries[query].collection], "find").andCallThrough();
      }

      multiquery(queries);

      for (var query in queries) {
        details = queries[query];
        expect(db[details.collection].find).toHaveBeenCalledWith(details.selector, details.fields)
      }
    })

    it("calls any subsequent modifiers on the find", function() {
      var query, details;
      for (query in queries) {
        details = queries[query];
        for (var modifier in (details.modifiers || {})) {
          spyOn(db[details.collection].find(), modifier).andCallThrough();
        }
      }

      multiquery(queries);

      for (query in queries) {
        details = queries[query];
        for (var modifier in (details.modifiers || {})) {
          expect(db[details.collection].find()[modifier]).toHaveBeenCalledWith(details.modifiers[modifier])
        }
      }
    })

    it("returns an array of the results, keyed to the query name", function() {
      var query, details, queryResults = {};

      // stub out the results of the find, so we can see what we get back
      for (query in queries) {
        queryResults[query] = {result: query};
        // we use toArray to turn cursors into results, so mock that here
        spyOn(db[queries[query].collection].find(), "toArray").andReturn(queryResults[query]);
      }

      results = multiquery(queries);

      // now see if for each named query, we got the right result
      for (query in queries) {
        expect(results[query]).toBe(queryResults[query])
      }
    })

    it("catches any errors and returns them as the result of the appropriate query", function() {
      error = {error: true};
      spyOn(db.vehicles, "find").andThrow(error);
      results = multiquery(queries);
      expect(results.cars.error).toBe(error);
      expect(results.routes.error).not.toBeDefined();
    })

    describe("querying a non-existent collection", function() {
      beforeEach(function() {
        queries.bogus = {
          selector: {privacy: 2},
          collection: "bogus"
        };
      })

      it("returns an error for that result", function() {
        results = multiquery(queries);
        expect(results.bogus.error).toBeDefined()
      })

      it("returns other queries as expected", function() {
        results = multiquery(queries);
        for (var result in results) {
          if (result !== "bogus") {
            expect(results[result].error).not.toBeDefined()
          }
        }
      })
    })
  })
})