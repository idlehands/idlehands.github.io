---
layout: post
title: ! "Switching adapaters on startup in Rails"
tags: [rails, patterns, adapters]
status: publish
type: post
category: articles
published: true
---

This will explain how to choose adapters for 3rd party APIs, based on the environment (or any other condition), on initialization of your Rails application. This was inspired by [José Valim’s Elixir post](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts) about using environment specific adapters for 3rd party services and the excellent Mix.Config in Elixir. I plan to write more about various ways to test and develop against 3rd party services, but this is a place to start.

## Laying some groundwork.
Before I go any further, I want to define what I mean by 3rd party services. This is really any dependency outside of your code base. Anything you have to call out to for your application to work out. In most cases, this means a service run by someone else, but if you’re working in a multiple service environment (SOA or monolith + micro services), your application is still relying on code that it doesn’t own. Hopefully, you are already on board with using adapters to abstract your 3rd parties. If not, please take time to read [Robert Pankowecki’s excellent Adapters 101](http://blog.arkency.com/2014/08/ruby-rails-adapters).
As mentioned, I plan to follow up with more posts with specifics on testing/developing adapters.
When working against 3rd parties in Rails, I commonly reach for VCR to help speed up testing and remove dependencies outside of my own code-base. I’ve been lucky enough to have access to sandboxes for most APIs I’ve worked against.

## Enough with the chit chat. Let’s look at some code.
Recently, I worked against outside dependencies where hitting the sandbox regularly wasn’t ok. That meant that anytime I wasn’t specifically working on the integration with that API, I needed to stub the calls out. The calls out were stubbed during testing as well. My predecessor in the code base had a class variable set at initialization that affected the flow:

{% highlight ruby %}
def get_burger_from_bob(customer)
  if @@stub_bobs_burgers
    {customer_id: customer_id, burger: {temp: "rare", size: 0.25, condiments: ["lettuce", "onion", "pickle"]}}
  else
    BobsBurgersGem.fetch_burger(customer.identity.try(:id))
  end
end
{% endhighlight %}

There are a couple of issues with an approach like this. @@variables are messy. They can often lead to hidden or confusing behavior and a lot of developers don’t understand them very well. Additionally, there is logic in the “production” block of code that will never be tested. That .identity.try(:id) is more ominous than it looks. When I refactored the code and removed identity as a nested object, the tests never broke.
So, then what do I propose? Going back to José’s post, I recommend having two adapters. One that is for real calls, going out to your 3rd parties and one that is a mock object, returning appropriate, usable responses without ever calling out of your application. The onus falls on the developer to make sure that the interface of the mock adapter matches the real one, but there are some tools that can help with that, too. Again, this is a place where I promise an additioanl post, but right now, I’m focusing on the switching pattern.
So, I’m proposing something like this at startup:

{% highlight ruby %}
case Rails.env
when "test"
  BURGER_CLIENT = Adapters::BobsBurgers::ClientMock
when "development"
  BURGER_CLIENT = Adapters::BobsBurgers::ClientMock
when "staging"
  BURGER_CLIENT = Adapters::BobsBurgers::Client
when "production"
  BURGER_CLIENT = Adapters::BobsBurgers::Client
else
  raise Exception.new("Environment: #{Rails.env} is not valid")
end
{% endhighlight %}

This assumes that we have wrapped the BobsBurgersGem in our own adapter and have written a mock adapter that matches the its interface.
Now, let’s look at the code that utilizes the constant:

{% highlight ruby %}
# before refactor
def get_burger(customer)
  BURGER_CLIENT.new(customer.identity.try(:id))
end
{% endhighlight %}

It’s a lot simpler, meaning easier to unit test the class containing it AND it exposes the .identity.try(:id) to testing, which would cause the test to break after identity was refactored away.

## Notes on style.
I’m a big fan of pretty looking code and I personally dislike the way that constants look. WHY_ARE_THEY_ALWAYS_YELLING? My first pass on this used a Camel case constant instead, but I eventually revised it because I was sacrificing the obviousness that that wasn’t a class but a value assigned somewhere for prettiness.
Some might wonder why I didn’t set the value from the result of the case statement. The assumption here is that you can do this for multiple 3rd party adapters and that different ones might need to be configured differently depending on what those 3rd parties offerings look like.
If you’re getting that far into the pattern, you might consider creating a configuration object as well, though it is up to you to decide if the payoff is there.

{% highlight ruby %}
case Rails.env
  ADAPTER_CONFIG = Configurator.new
when "test"
   ADAPTER_CONFIG.burger_client(Adapters::BobsBurgers::ClientMock)
   ADAPTER_CONFIG.fries_client(Adapters::JimsFries::ClientMock)
when "development"
   ADAPTER_CONFIG.burger_client(Adapters::BobsBurgers::ClientMock)
   ADAPTER_CONFIG.fries_client(Adapters::JimsFries::Client) # Not a typo. Mix and match as needed.
when "staging"
   ADAPTER_CONFIG.burger_client(Adapters::BobsBurgers::Client)
   ADAPTER_CONFIG.fries_client(Adapters::JimsFries::Client)
when "production"
   ADAPTER_CONFIG.burger_client(Adapters::BobsBurgers::Client)
   ADAPTER_CONFIG.fries_client(Adapters::JimsFries::Client)
else
  raise Exception.new("Environment: #{Rails.env} is not valid")
end

# use case:
burger_client = ADAPTER_CONFIG.burger_client.new
{% endhighlight %}

## Coping with Spring.
This works pretty easily and cleanly. The one place where it caught me up was working in development and testing while using Spring. Spring likes to cache everything from the initializer, so we need to have it watch all of our adapters and always force a reload of the adapters file. This adds a tiny bit of time to startup, but it shouldn’t be noticeable.

{% highlight ruby %}
if defined?(Spring)
  Spring.watch(Dir["#{Rails.root}/lib/adapters/**/*.rb"])

  Spring.after_fork do
   Kernel.silence_warnings { load("#{Rails.root}/config/initializers/adapters.rb") }
  end
end
{% endhighlight %}

This allows easy swapping of the adapters, for one-off development needs, without Spring messing with you.

## Wrapping up.
This is really just a small part of the pattern. Having usable and interchangeable adapters is really the first step, but I plan to write that up soon.
I’m open to feedback about what could/should be done differently, but this has worked for me in a live app. Cheers.
