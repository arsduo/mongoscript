[![Build Status](https://secure.travis-ci.org/arsduo/mongoscript.png)](http://travis-ci.org/arsduo/mongoscript)

#MongoScript#

An experimental library designed to make server-side Javascript execution in MongoDB easy, fun, and profitable.

###Hey kids, this toy is for novelty use only###

This library isn't "experimental" only in the sense that I'm trying out new code to see where it leads -- MongoScript is a thought experiment more than a production helper, for one simple reason.  As the MongoDB [server-side code execution](http://www.mongodb.org/display/DOCS/Server-side+Code+Execution) puts it:

> Note also that [Javascript] eval doesn't work with sharding. If you expect your system to later be sharded, it's probably best to avoid eval altogether.

If you're building a small-to-medium-sized system that you know will never grow huge, you may be able to use MongoScript to very cool effect.  I wouldn't recommend it for any kind of "we're gonna scale it  to the moon!" kind of product, though.  Disentangling Javascript functions and reimplementing them in Ruby so you can shard your growing database doesn't sound like my kind of fun.

###Performance###

There's also no guarantee that using Javascript to perform semi-complex queries is actually worth it -- Javascript can be significantly slower.  I'll post some performance statistics soon.

###The cool stuff###

You understand all that, you just want to hack some server-side code for the fun of it?  Let's get to it!


####More readme coming soon!####