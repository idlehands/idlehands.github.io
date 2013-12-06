---
layout: post
title: ! "Configuration Management: The Upstream Cookbook/Module Fallacy"
tags: [configuration management, chef, puppet, ops]
status: draft
type: post
category: articles
published: false
---

I see a lot of organizations doing something that they actively promote as good
practice and which I think is often counter-productive and potentially even
crippling to productivity. I will call it "the upstream cookbook/module
fallacy." This is the idea that it is efficient and productive to focus the
use of a configuration management system such as Chef or Puppet around the
consumption of upstream modules which you then do not touch. My intention is
not to criticize anyone, but to make a point based on my own experience about
how to save yourself and your organization a potentially huge time cost.

Configuration management is by definition company- and application-specific.
You are setting out to write custom code that when taken in aggregate, will be
entirely different from everyone else's. The whole idea in fact, is that you
have all the business logic concerning building and configuring your systems in
one place--where it is *centrally managed and your results are repeatable*. As
I see it, that last bit is the part that makes configuration management
critically important. This is the thing that made everyone want to use it to
begin with and it should still be the focus. You are taking the configuration
of your systems, with all your company-specific configuration, and putting it
into code where anyone can see how things are built and repeatably build them
with consistent results.

But, you get this other benefit as a side-effect: configuration management
makes it easy to rapidly build out systems using modules or cookbooks that
other people have built. This is a big win. Like libraries or gems or eggs,
or whatever your language-specific nomenclature is, pre-packaged modules
and cookbooks can deliver a lot of bang for your buck. You add a few lines
to your configuration management system and you have NGiNX deployed, for
example. Productivity is immediately increased and everyone is happy.

