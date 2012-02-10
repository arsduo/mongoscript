#MongoScript#

An experimental library designed to make server-side Javascript execution in MongoDB easy, fun, and profitable.

###Hey kids, this toy is for novelty use only###

This library isn't "experimental" only in the sense that I'm trying out new code to see where it leads -- MongoScript is a thought experiment more than a production helper, for one simple reason.  As the MongoDB [server-side code execution](http://www.mongodb.org/display/DOCS/Server-side+Code+Execution) puts it:

> Note also that [Javascript] eval doesn't work with sharding. If you expect your system to later be sharded, it's probably best to avoid eval altogether.

If you're building a small-to-medium-sized system that you know will never grow huge, you'll be able to use MongoScript to very cool effect.  I wouldn't recommend it for any kind of "we're gonna scale it  to the moon!" kind of product, though.  Disentangling Javascript functions and reimplementing them in Ruby so you can shard your growing database doesn't sound like my kind of fun.

What's that you say, though?  You understand all that, you just want to hack some server-side code for the fun of it?  Happy to oblige!

###The cool stuff###

Now that those unpleasantries are behind us, it's time for the cool stuff: what we can do with MongoDB and Javascript.

