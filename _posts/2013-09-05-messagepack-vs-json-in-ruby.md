---
layout: post
title: ! "MessagePack vs JSON in Ruby"
tags: [messagepack, msgpack, json, development]
status: publish
type: post
category: articles
published: true
---

[MessagePack](http://msgpack.org/) (shorthand: msgpack) gives us a big
performance boost when serializing data to our data store. JSON is the reigning
champ for data serialization protocols on the web because it is easy to use,
nearly universally supported, human readable, relatively efficient, and
compresses very well. I love JSON and we use it extensively at
[MyDrive](http://mydrivesolutions.com).

But, there is a use case where we get a big win from using MessagePack instead.
We store a lot of [time series data into Cassandra](/cassandra-vs-mongo) and
that data is about 16 KB per time slice when encoded as JSON. That's a pretty
hefty chunk of data at the rate at which we write it. The size is less of a
concern though than the time it takes to serialize it and deserialize it,
because we often deserialize hundreds of JSON blobs at once. Deserializing
alone takes us about 27% of the job time for this particular stage of our work
flow. That 27% is on average a 1/2 second with MessagePack, for reference. We use
JSON over the wire in most places, but to the data store we write MessagePack.

We made the decision to use MessagePack some time ago. But, I recently switched
a lot of our current JSON code over to use Peter Ohler's optimized JSON library
for Ruby, [Oj](https://github.com/ohler55/oj). It's really fast: nearly 8x the
performance of YAJL for our over-the-wire data. 

I thought maybe now it would be faster than MessagePack for the data store
also, and that perhaps we should look at switching. Some testing proved that
this was not correct: MessagePack still outperforms JSON deserializing in Ruby,
even using this excellent and highly optimized library. It's still 2x the speed
serializing and 1.6x when deserializing. Keep in mind that this is about a 16
KB document in JSON and 14 KB in MessagePack.

| Encoding      | Size in Bytes
|:-------------:|--------------:
| JSON          | 16402
| MessagePack   | 14063

When testing performance in Ruby I often reach for `pry`, and `benchmark`.  I
test things out directly in the REPL. Doing so, I ran some numbers. I use the
`Benchmark.bmbm` method here to try to rule out garbage collection timing
interference and other factors. You can [read about it
here](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/benchmark/rdoc/Benchmark.html#method-c-bmbm)
if you want to know more. Benchmarks were on Ruby 1.9.3.

I did this a number of times but here are some exemplary numbers on my 2011
MacBook Air:

## Deserializing
{% highlight ruby %}
sleipnir(default)> Benchmark.bmbm { |bm| bm.report { 1000.times { MessagePack.unpack(msg_packed) } } }
Rehearsal ------------------------------------
   0.400000   0.020000   0.420000 (  0.410992)
--------------------------- total: 0.420000sec

       user     system      total        real
   0.390000   0.010000   0.400000 (  0.408010)
=> [  0.390000   0.010000   0.400000 (  0.408010)

sleipnir(default)> Benchmark.bmbm { |bm| bm.report { 1000.times { Oj.load(jsonified) } } }
Rehearsal ------------------------------------
   0.390000   0.000000   0.390000 (  0.654920)
--------------------------- total: 0.390000sec

       user     system      total        real
   0.460000   0.010000   0.470000 (  0.680867)
=> [  0.460000   0.010000   0.470000 (  0.680867)
]
{% endhighlight %}

That 'real' number in the bottom right is the one we care about most. Doing
1000 calls took 0.408 seconds with MessagePack and 0.681 seconds with Oj, a
1.6x improvement.

## Serializing
{% highlight ruby %}
sleipnir(default)> Benchmark.bmbm { |bm| bm.report { 1000.times { data.to_msgpack } } }
Rehearsal ------------------------------------
   0.070000   0.000000   0.070000 (  0.074048)
--------------------------- total: 0.070000sec

       user     system      total        real
   0.070000   0.000000   0.070000 (  0.073553)
=> [  0.070000   0.000000   0.070000 (  0.073553)
]

sleipnir(default)> Benchmark.bmbm { |bm| bm.report { 1000.times { Oj.dump(data) } } }
Rehearsal ------------------------------------
   0.160000   0.010000   0.170000 (  0.164234)
--------------------------- total: 0.170000sec

       user     system      total        real
   0.150000   0.000000   0.150000 (  0.156360)
=> [  0.150000   0.000000   0.150000 (  0.156360)
{% endhighlight %}

So 0.074 seconds for MessagePack and 0.156 seconds for Oj.  That's over a 2x
improvement in speed.

## Compression
There is one place where JSON is the clear winner with our data, though. JSON
gzips very well and when compressed is noticeably smaller than the MessagePack
data. Note that gzipped here means the normal gzip mode, not highest compression.

| Encoding      | Size in Bytes when gzipped
|:-------------:|---------------------------:
| JSON          | 1077
| MessagePack   | 1171

Conclusion
----------

Oj is a very good and fast JSON library and if you're using Ruby you should
consider it.  JSON is great over the wire, and if we were more concerned with
space than deserializing speed, we'd be using JSON. But for performance,
MessagePack has it, hands down and that is why we use it for serializing to
our data store.
