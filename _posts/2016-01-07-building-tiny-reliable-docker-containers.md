---
layout: post
title: ! "Building Tiny, Reliable Docker Container Images"
tags: [docker, go, s6]
status: publish
type: post
category: articles
published: true
---

Building good, clean Docker container images is a bit of an art, and there is a lot
of conflicting advice out there about how to do them properly. I'd like to
share some thoughts gained from running Docker containers in production for two
years at New Relic. Some of this is discussed in the O'Reilly book *[Docker: Up
and Running](http://shop.oreilly.com/product/0636920036142.do) that I co-wrote
with Sean Kane. There are all kinds of best practices we could talk about.
Here I'll focus on a few best practices aimed at making things small and reliable.

Size Matters
------------

At scale you're going to be shipping around tens, hundreds, or thousands of
copies of your image. Docker's distribution mechanism means that each host will
need to have a copy of all of the layers of your image locally. If your image
is 800MB then you're going to have 800MB of data to pull at least once. There
are a few prongs of attack to get that size down to a minimum. Some of these
intermesh nicely with also making your images more reliable, as you'll see.

###Use Standard Base Images

**Savings**: Depends. Big environments will save a lot, smaller ones won't.

Build all of your production containers on top of a simple set of base images.
If your base image is big (usually meaning it's based on a full OS distro),
then with this pattern you still have to pull all of those layers, but you
don't have to do it for every application on each deployment. Since the layers
are shared between apps, the overhead is reduced. There are all kinds of
commonality benefits to be had here, too, so it's a good pattern even if you
don't need the space.

I recommend constructing an image hierarchy with a build job that rebuilds,
re-tags, and re-pushes all the affected base images when any upstream node is
changed in the tree. This is a really nice pattern that as worked out well in
my experience. With this pattern of building all the affected nodes in the tree
whenever a change is pushed, anyone who will build an application image
derived from one of those base layers will get the newest version of the base
they depended on, even if it is an upstream image that changes. It also means
you detect breaking changes to downstream images immediately, not when an
application build fails down the road.

Here's a linear example:

  OS base -> Webapp base -> Ruby webapp -> Your Application

The behavior you want is to make sure that if security updates were applied to
the "OS base" image, that your "Webapp base", and "Ruby webapp" are
automatically rebuilt, re-pushed, and re-tagged. Or imagine that the Nginx
config in "Webapp base" was just improved. You want all future builds of "Your
Application" to pick them up even though it's built from "Ruby webapp" and not
"Webapp base" directly.

###Don't Ship a Whole Linux Distribution

***Savings***: Huge.

If you're building and deploying Docker containers `FROM ubuntu` or `FROM
centos` and the like, then you may be causing yourself a lot of unecessary
pain. In some cases this is the right thing to do. But for many applications
you can get away with much less. I'll talk about the MVP here in the next
section. But let's assume that you need a shell and maybe some other tools to
bootstrap your application. That's why you're using one of the big distro base
images. The good news is that there are great alternatives out there. I won't
go into all of them, I'll just tell you about my favorite: Alpine Linux. This
is a tiny distribution, aimed at embedded systems and other small
installations. It's perfect for containers because it has a full package
manager, a lot of available packages, and there is [a good Docker base
image](https://github.com/gliderlabs/docker-alpine) being maintained.

So, next time try `FROM gliderlabs/alpine:3.3` and see if it works for you.

###Statically Link Your Applications

**Savings**: Potentially huge. In many cases no benefit.

If you can get away with it, you can ship the most minimal application of all:
your application binary and assorted supporting files. Rather than even using
Alpine Linux as your base, here you just declare `FROM scratch`. This is a
great way to ship Go applications, or Rust, or C, or other compiled languages
where the application artifact can be a statically linked binary. If you're
running a JVM, or a Python, Ruby, or Node app, then this is probably not a
solution for you. But if you can get away with it, there is basically 12KB of
overhead here on top of your application. That's pretty minimal! Your
`Dockerfile` then shrinks to a few lines, with `FROM scratch` and then adding
your application and its configs.

Process Management is Important
-------------------------------

You need a program running at the top of your container that is meant to be run
as PID 1 on a Linux system. That process is usually SysV `init` or Upstart, or
Systemd on the major distributions. You need something like that in your
container. Phusion [wrote a good
post](http://phusion.github.io/baseimage-docker/) explaining why this is
important so I won't rehash that here. Suffice it to say that you need a real
PID 1 process at the top of your container tree. But there are other reasons.

There is a very worthy goal in the Docker community of running as little in
your container as possible. I applaud that. But reality is a harsh master and
it turns out that in widespread production deployments lots of things go wrong
no matter how well you build them. And as they get more fluid, with changes
flying constantly, they break more often. The best solution here is to use a
platform that schedules your containers to hosts and manages their life cycle.
Examples are Mesos with Marathon, Kubernetes, Deis, and friends. Even so, it's
often the case that you need to run more than one process in your container and
because of that you must have something that makes sure that dependency inside
the container is maintained. Docker and outside schedulers can see the
container but if one process in the container dies they may not notice. Don't
go overboard running lots of things in a container. Your container should do
one thing. But doing one thing doesn't mean you must have one process.

Enter the process manager. A lot of alternatives exist in this space. But you
want something that can act both as a real PID 1 and also does active process
management. Phusion recommends `runit` which is a perfectly fine solution. If
you are running a big distro, you can easily use Upstart or `systemd`. I have
used `supervisor` here extensively and can recommend its robustness, but it
doesn't handle the other duties of PID 1 (reaping children, signals, etc).
Also, a negative is that it needs a whole Python environment which can add
25-40MB to your container size.

My new favorite in this space is [Skaware's
S6](http://skarnet.org/software/s6/), a not-that-well-known alternative that is
dead simple to use and configure. It's minimalist but without giving up
ability. The binaries are statically linked, very small, and each do one thing
(take that, `systemd`). Installing it in your container image involves unpacking
a single tarball and dropping a config file.

One final point in this section. If you're not running a distriuted scheduler,
you owe it to yourself to use a process manager, even if there's only one other
process in your container. Without something managing your application health,
you're relying on Docker to restart your dead container for you. My experience
says that's a much worse than 50-50 proposition. A process manager will make
sure your container stays where you put it. Without one, you're on an upside
down roller coaster with no safety bar.

Conclusion
----------

That's some coverage of a few simple ideas that can have a big impact on the
reliability and sustainability of your Docker images. Docker is a great tool
but getting the platform right around is not trivial. This advice is based on
two years of real production Docker use where we shipped 75+ application
deployments on Docker per day. It should stand you in good stead.
