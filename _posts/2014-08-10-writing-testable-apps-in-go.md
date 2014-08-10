---
layout: post
title: ! "Writing Testable Code in Go (golang)"
tags: [go, golang, testing, development]
status: publish
type: post
category: articles
published: true
---

If you are coming from Ruby or another dynamic language you are used to mocking
and stubbing extensively for testing. This works fabulously well in Ruby, for
example, where you can easily modify a class or object at runtime when testing
it. Because Go is strongly typed and statically compiled, mocking and stubbing
is harder to achieve and far less flexible. You can do it to an extent, but
you're really working against the grain of the language. But that doesn't mean
that you can't test your code just as well.

The key to testable code in Go is using interfaces. When I started to write
production Go code about 9 months ago, I was given that exact piece of advice
and well, it was less than enlightening. It was not immediately obvious how
interfaces solve this problem. My first attempts worked fine, but required
writing a lot of needless code implementing other people's interfaces for test
stubbing. It took me awhile to realize how to properly leverage Go's powerful
interface mechanism. This is what I learned and it has drastically improved the
testability of my Go code.

##Dependency Injection

You really must be injecting all of your dependencies.

Dependency injection is good coding practice in most languages, but in dynamic
languages you can get away with isolating dependencies with runtime magic and
with stubbing in your test code. In Go you need to always inject your
dependencies since you can't (mostly) patch things at runtime in a safe way.

Here's some sample Go code showing the injection of a dependency. Let's say we
need to be able to get some JSON data from the web and then do something with
it.  In the real code I want to get this from the web with an HTTP request, but
in testing, I want to test my logic not whether I can make an HTTP request.  To
remove the dependency from my code, I pass in an `HttpResponseFetcher` that
knows how to get things from the web.

Yes, there are libraries that let you handle HTTP testing without doing this,
but this is an example that I think is easy to understand. And in many ways
this is better, more flexible code. Here we'll require in a dependency in the
method signature.

{% highlight go %}
func populateInfo(fetcher HttpResponseFetcher, parsedInfo *Info) error {
	response, err := fetcher.Fetch("http://example.com/info")

	if err == nil {
		err = json.Unmarshal(response, info)

		if err = nil {
			return nil
		}
	}

	return err
}
{% endhighlight %}

There isn't that much involved in this code. We have a dependency on an
`HttpResponseFetcher` which will be passed in and then we simply call a method
on it (`fetcher`) to retrieve a `[]byte` of data, then unmarshal the JSON into a
struct we were passed.

Other than the fact that `fetcher` implements an interface, there are a couple
of things that are worth noting here. One is that we only call a single method
on `fetcher` and another is that it returns a simple `[]byte`. A `[]byte` is
trivial to mock statically in test code.

##Using Interfaces

The dependency injection gets us a handle on the data that will be manipulated
in the function. We can pass in an `HttpResponseFetcher` implemented however
we like and the code will be happy with it. Here's the whole definition for our
interface:

{% highlight go %}
type HttpResponseFetcher interface {
	Fetch(url string) ([]byte, error)
}
{% endhighlight %}


Our real production implementation of the `HttpResponseFetcher` looks something
like this:

{% highlight go %}
func (Fetcher) Fetch(url string) ([]byte, error) {
	response, err := http.Get(url)
	if err != nil {
		return nil, err
	}

	defer response.Body.Close()

	contents, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}

	return contents, nil
}
{% endhighlight %}

That talks to the network, reads the response and packages it up into a
`[]byte`. But when we test this we just write a `StubFetcher` that implements
the `Fetch` method and we're good to go. It's easy to implement:

{% highlight go %}

var infoOutput []byte = []byte(
	`{ "Environment": "production" }`
)

var StatusOutput []byte = []byte(
	`{ "Status": "up" }`
)

type stubFetcher struct{}

func (fetcher stubFetcher) Fetch(url string) ([]byte, error) {
	if strings.Contains(url, "/info") {
		return infoOutput, nil
	}

	if strings.Contains(url, "/status") {
		return statusOutput, nil
	}

	return nil, errors.New("Don't recognize URL: " + url)
}
{% endhighlight %}

Here we just look at the URL that was requested and return a static
`[]byte` that has the contents we want to test with.

So our call inside our test method would pass in the stubbed `Fetcher`
like this:


{% highlight go %}
var info *Info
var stub stubFetcher

// We would make some assertions around this:
populateInfo(stubFetcher, info)
{% endhighlight %}

##Use Your Own Interfaces Most of the Time

Here's the thing that took the longest to figure out, and which I think
will be the biggest help to those on the same learning path:
you should usually inject your own interfaces, not stdlib or library-defined
interfaces. That was not apparent at first, but here's why that's powerful.

In the code above, by using our own interface, we can actually handle more than
one URL in the same stubbed method. This is useful for things where you make
more than one request in a function. Because we started with our own interface
from the beginning, when we add a second request in the same function, we don't
have to go back and rewrite our tests to support it.

Here's what we might have done: we could have passed in a `Reader` and stubbed
it in testing and passed in an HTTP response body in real usage. But when we
needed to make more than one request in the same function, we couldn't then
do that easily because our stub `Reader` wouldn't know which request had been
made.

There is a more powerful reason, though. Implementing many interfaces requires
that you have many methods. So to make a stub you would *need to implement all
of them*.

But remember that in Go anything that implements the correct method signatures
is accepted as an implementation of the interface. So if you don't *need* all of
those other methods in your code, don't use that interface. Define one of your
own that only includes the methods you actually need. That lets your stub be
one or two methods in many cases. And that's easy to implement.

A perfect example are the various `Socket` interfaces. Many of them are 15 or
more methods. If you made a stub Socket to pass to your function in testing,
you would have a lot of work on your hands. If you define your own interface
and pass that instead, you can easily test it. On top of that, your code is
now even more flexible because your requirements for your dependency are very
narrowly scoped to only the methods you really care about.

## Conclusion

These are some of the tools I have found for writing testable code in Go. As
is usually the case, testable code is also better written.  I hope this article
helps direct some other people down a path it took me some time to discover.

