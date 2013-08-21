---
layout: post
title: ! "Cassandra vs MongoDB For Time Series Data"
tags: [cassandra, mongodb, development]
status: publish
type: post
category: articles
published: true
---

This is how we got a big win by switching from MongoDB to Cassandra.

Background
----------

MyDrive has an AWS cloud-hosted telematics data processing platform with a
chain of Resque workers doing the heavy lifting. Several of these phases
are particularly intensive and we have a Graphite dashboard that tracks time
spent in just those workers. We naturally graph lots of things about the
pipeline, but this is one of them.  We call the time spent in the worker TOQ
(time-out-of-queue). This is one of the useful metrics for tuning the number of
each worker in the pipeline.

Being a telematics company, we process a lot of time series data, and the
initial pipeline that was built did a lot of work with MongoDB. This choice was
made early on and it was supposed to be a temporary one. MongoDB behaved
reasonably well, but the unpredictability of the load times for different sizes
of work was troubling and made pipeline tuning difficult.  Some queries would
return 30 documents and others 300.  With the way Mongo is designed (and most
SQL datastores also), this resulted in a varying IO load. The query for
30 documents would return much faster than the query for 300. Neither was
particularly quick, either, even with good indexing and relatively decent instances.

Futhermore, we were going to have to scale our Mongo instances vertically to at
least an extent, and we weren't excited by the long term economy of doing that.
In order to get decent performance we were already running multiple extra large
instances.

Solution
--------

From the beginning we wanted to use Cassandra, which I had previously run at
[AboutUs](http://aboutus.org) starting from version 0.5. It has always proven
itself to be intensely reliable, predictable, and resilient. Those features,
combined with the horizontal scalability make it a pretty killer data store.
For reasons we won't get into now, this wasn't possible to start with.

The normal data flow is that we write some data, read it back, modify it, write
it, and read it back one more time. These actions happen in different workers.
This isn't the ideal workload for Cassandra, but it's a reasonably good fit
because of how we query it.

Cassandra is really good for time-series data because you can write one column
for each period in your series and then query across a range of time using
sub-string matching. This is best done using columns for each period rather
than rows, as you get huge IO efficiency wins from loading only a single row
per query. Cassandra has to at worst do one seek and then read for all the
remaining data as it's written in sequence to disk.

We designed our schema to use IDs that begin with timestamps so that they can
be range queried like this, with each row representing one record and each
column representing one period in the series. All data is then available to 
be queried on a row key and start and end times.

With the way our workload behaves, it seems that with MongoDB the number of writes
was actually noticeably impacting read performance. With Cassandra, this does not
seem to be the case for our scenario.

Comparison
----------

The graph below shows the better part of a year of performance, and the blue
line is the one most affected by the performance of the data store. It should
be obvious from the number of drops in the times that we were both tuning
MongoDB and scaling the hardware to keep performance reasonable. But none of
these changes were as effective as the move to Cassandra.

We phased MongoDB out by first turning off writes to it, then eventually
turning off reads from it as well. These are clearly marked on the graph.

Worth noting is that not only did the performance massively improve (for around
the same AWS spend, it should be said), but the predictability is hugely
improved as well. Notice how much flatter that blue line is compared to when
Mongo was in heavy use.

For us this has been an unequivocally big win and I thought it was worth sharing
the results.

![Cassandra vs MongoDB](/images/CassandraVsMongo.png)
