---
layout: post
title: ! "Continue statements with Labels in Go (golang)"
tags: [go, golang, development]
status: publish
type: post
category: articles
published: true
---

Flow control of nested loops can be a pain. And because Go uses `for` loops in
great abundance, you hit this problem more often than in some other languages.
But Go also provides a clean solution. `continue` statements in Go can take a
label as an argument and that makes for much cleaner code with nested loops.

Other languages like Perl and Java have the same mechanism and Ruby has `throw`
and `catch` [for jumping
contexts](http://stackoverflow.com/questions/1352120/how-to-break-outer-cycle-in-ruby),
for example. But I don't often come across code that controls nested loop flow
this way, in any language. So, I thought a short article was in order because
this use of labels is powerful and nice. Here's how it works.

##Nested Loops the Hard Way

You've probably written code like this before, in Go or some other language, to
continue iteration on an outer loop from inside an inner loop:

{% highlight go %}
for _, item := range list.Items {
	found := false

	for _, reserved := range reserved.Items {
		if reserved.ID == item.ID {
			found = true
			break
		}
		... do some other work ...
	}

	if found {
		continue
	}

	... do some other work ...
}
{% endhighlight %}

This is not nice to look at, and it requires that we keep some state in the
`found` boolean. There's not really anything technically wrong with it, but
it's hard to follow when you first read it, and debugging it later can be
annoying if there is more going on in the code than our simple loops above.

Anything that introduces the need for more context when reading your code
means future you or other teammates are more likely to get it wrong.

But there is a better, simpler way.

##A Better Way

This is where labels come in. If you're not familiar with them, you've
probably seen labels where people have used `goto` statements. They're used to
tell the compiler that we care about this place in the code and we're going to
transfer execution to it at some point in the future. If you're snickering
about `goto` statements, consider that the Go compiler uses them extensively.
But back to labels. They aren't only useful for `goto` statements, you can also
use them with `continue`.

Let's take that same outer/inner loop combination from above and rewrite it
with a label that we'll pass to `continue`. We'll call our label `OUTER`.

{% highlight go %}
OUTER:
for _, item := range list.Items {
	for _, reserved := range reserved.Items {
		if reserved.ID == item.ID {
			continue OUTER
		}
		... do some other work ...
	}
	... do some other work ...
}
{% endhighlight %}

Here we've removed all that accounting with the `found` variable and made a
single obvious call to continue iteration from our `OUTER` label. When we make
that call, we break out immediately from the inner loop without doing any more
work, just like with a normal `continue` call. But we also jump back to the
beginning of the outer loop as well, skipping any code that came after the
inner loop.

It should be noted that I've used the `OUTER` label here because it's easy to
understand. But this could just as easily be anything arbitrary. Using something
meaningful in context is always the best idea.

##But Keep It Simple

Using labels to continue from inner loops can really clarify your code,
increase execution speed slightly, and reduce unnecessary lines. They are a
nice tool to have in your belt. But you shouldn't use it in place of breaking
useful code out into functions. It's great for simple cases like the one above
where we're not doing a lot in either loop. But if you were to do much more,
you should probably put that inner loop in a function and call it instead. You
can then continue the outer loop based on the result. That will be cleaner code
yet, and well-named functions make the intent of a block of code much more
explicit. But often the simple label is the right solution.

If you are now wondering whether there are other statements in Go that can use
this mechanism, consider the [break
statement](http://www.goinggo.net/2013/11/label-breaks-in-go.html).
