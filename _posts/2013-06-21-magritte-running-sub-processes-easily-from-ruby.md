---
layout: post
title: ! 'Magritte: Running sub-processes easily from Ruby'
tags: []
status: publish
type: post
category: articles
published: true
meta:
  _edit_last: '1'
  _edit_lock: '1371842973'
---
At [MyDrive](http://mydrivesolutions.com/) we have a few hefty
binaries written in C++ that are used as part of our main telematics
data processing pipeline.  One of these is built as a library and
tied in to Ruby via FFI.  This C++ is all somewhat legacy code and
the other binaries are built to pipe data in and out on the command
line.  Rather than adapt them all to build as libraries, and write
the FFI wrappers, I wrote a nice set of tooling to make it easy to
run them as sub-processes from our pipeline workers.  It had a not
very original name at first, but Gavin Heavyside suggested Magritte
because of his painting [The Treachery of Images](http://en.wikipedia.org/wiki/The_Treachery_of_Images),
with the famous quote *Ceci n'est pas une pipe*. "This is not a pipe"

<img src="https://raw.github.com/relistan/magritte/master/assets/ceci-nest-pas-une-pipe.jpg" alt="" />

So I released the [Magritte gem on rubygems.org](http://rubygems.org/magritte).

The idea is that you have some source of data and you want it to
go somewhere just like a command line pipe.  The source needs to
be a Ruby `IO` object and the output can either be an
`IO`, or a block implementing your data handling routine. 
I also provided a `LineBuffer` class to make it easy to
write an output block that works on the output line by line.

Here's an example of what you can do with it:

{% highlight ruby %}
Magritte::Pipe.from_input_file('some.txt')
.separated_by("\r\n")
.line_by_line
.out_to { |data| puts data }
.filtering_with('grep "relistan"')`
{% endhighlight %}

Much more information is available in the [README on Github](https://github.com/relistan/magritte).
