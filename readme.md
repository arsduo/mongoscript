[![Build Status](https://secure.travis-ci.org/arsduo/mongoscript.png)](http://travis-ci.org/arsduo/mongoscript)

#MongoScript#

An experimental library designed to make server-side Javascript execution in MongoDB easy, fun, and profitable.

###Hey kids, this toy is for novelty use only###

This library isn't "experimental" only in the sense that I'm trying out new code to see where it leads -- MongoScript is a thought experiment more than a production helper, for one simple reason.  As the MongoDB [server-side code execution](http://www.mongodb.org/display/DOCS/Server-side+Code+Execution) puts it:

> Note also that [Javascript] eval doesn't work with sharding. If you expect your system to later be sharded, it's probably best to avoid eval altogether.

If you're building a small-to-medium-sized system that you know will never grow huge, you may be able to use MongoScript to very cool effect.  I wouldn't recommend it for any kind of "we're gonna scale it  to the moon!" kind of product, though.  Disentangling Javascript functions and reimplementing them in Ruby so you can shard your growing database doesn't sound like my kind of fun.

###The cool stuff###

You understand all that, you just want to hack some server-side code for the fun of it?  Let's get to it!

First, what are a few things you could do with Mongo server-side Javascript?

* Multiquery: execute multiple find queries in one call.  (See Performance below.)
* Join: Mongo's (in)famous for not offering native joins, but a Javascript method to fetch from collection A and then get any referenced records from collection B won't be hard.
* Easy maintenance: why transfer records and updates back forth between your web server and your database, when you can do everything at localhost speed?

You'll notice a theme: making one connection to the database and executing multiple operations.  That's where server-side Javascript shines: it's a language you already know that can do whatever you need it to, all within the context of your server.

(more ideas/explanation coming soon)

###Performance###

Just to show what a Javascript-based approach to Mongo can do, let's take a look at multiquery, one of the first tools built into MongoScript.  This lets you execute multiple find queries easily using a single database connection.

When run locally, it doesn't make a significant difference:

```
# Macbook Pro running Ruby and MongoDB locally
# 100 run average
Traditional execution took 0.38300072999999996
Multiquery execution took  0.37415497999999997
```

But check out what happens if the web server and the database aren't on the same machine:

```
# Test web and MongoDB servers in the same EC2 location
# 100 run average
Traditional execution took 0.02256884963
Multiquery execution took  0.01187204267
```

The results hold up over multiple runs, and I suspect would be even stronger with writes.

###Coming Soon###

A more detailed readme, with usage instructions and so on.

###Note on Dependencies###

Since this is currently experimental/for fun, I'm relying on ActiveSupport for HashWithIndifferentAccess and Concern.  I acknowledge this restricts the gem to projects where ActiveSupport is an option, but should be easy enough to rip out if someone wants to use this seriously.