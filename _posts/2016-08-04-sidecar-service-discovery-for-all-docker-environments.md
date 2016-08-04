---
layout: post
title: ! "Sidecar: Service Discovery for all Docker Environments"
tags: [docker, sidecar, go]
status: publish
type: post
category: articles
published: true
---

![Sidecar](https://github.com/newrelic/sidecar/raw/master/views/static/Sidecar.png)

Great, you have a Docker system up and running. Maybe you run stuff on your dev
box in a standalone Docker instance. Maybe you are just deploying containers
with Ansible or other stateless tools. Maybe you even have some stuff running
in Kubernetes. Or Mesos. But integrating a dynamic container environment into
an existing static one, or even just biting off the move to Kubernetes or
Mesos, is a challenge.

At New Relic and at Nitro we went through that. What we wanted was a platform
that would work on everything from a single laptop up to a large cluster,
either running only Docker, not running any containers, or running a full Mesos
system. So we built [Sidecar](https://github.com/newrelic/sidecar), a service
discovery platform that works on a solo laptop and also on a large, distributed
cluster: either in the data center or the cloud. (A demo from a year ago is [on
Youtube](https://www.youtube.com/watch?v=VA43yWVUnMA)).

Sidecar was designed to be Docker-native but to also allow older or larger
static systems like data stores, or legacy apps to participate in the service
discovery cluster. There is no centralized software to maintain: no etcd, no
zookeeper, no Consul. It's fully distributed. It only needs Docker or a static
discovery configuration to work. So you can share services between Docker-only
systems, statically deployed systems (e.g. databases), or services which are
running in Kubernetes or Mesos. You can call into your new Kubernetes cluster
from your legacy systems just by running Sidecar on those systems. It's a Go
static binary, and is under 20MB in size.

## How it Works

Each host that will participate in service discovery runs a copy of Sidecar.
This is true whether you are consuming services or publishing them. The
Sidecars use a SWIM-based gossip protocol (derived from that used in
Hashicorp's Serf) to communicate with each other and exchange service
information on an ongoing basis. Changes are propagated across the network in a
viral fashion and converge quickly. There are no DNS TTLs or caching to worry
about or delay convergence. Each host keeps its own copy of the shared state.
That state is in turn used to configure a local proxy, which listens locally
and binds well known ports for each service. We've used a well known IP address
on each system to bind the proxy and given that IP a common DNS name.

So at Nitro we can, from any host in the network, get a load-balanced
connection to any service by making an HTTP request to e.g.
`http://services:1005` where `1005` is a well-known port for the service we
want to consume. If you wanted to distribute an `/etc/services` file or use
LDAP or some other means to share port names, this could then become
`http://services:awesome-svc`.

**A critical point is that Sidecar publishes the health status** of those
service endpoints. In this way proxies will only point to those endpoints which
have been demonstrated to be healthy. Health change events are exchanged over
the gossip protocol.

Let's say I have two services, `awesome-svc` and `good-svc` that communicate.
`awesome-svc` needs to be able to call out to `good-svc` which may be running
on this host, or some other hosts. It might be a static service that never
moves, or it might be deployed on a Mesos cluster. But, we have decided that
`good-svc` will have the assigned port of 10001. Sidecar is running on all the
hosts involved, so they are a single "cluster" as far as service discovery is
concerned. Sidecar manages an HAproxy that we have running everywhere bound to
the **same locally-configured IP address** of `192.168.168.168` on each host.
So all `awesome-svc` needs to have in its configuration is a hard-coded line
that says that `good-svc` has the URL of `http://192.168.168.168:10001`. This
will be valid on all hosts in the network and **will hit the local HAproxy on
this box** not a centralized load balancer.

From the standpoint of running this on Docker, you run one or two containers
(your choice) on the hosts involved and this all just works. If you go with all
of our defaults, there is not really more to it than that. For statically
discovered services, you need to run the Sidecar binary and export a JSON
configuration file that tells the other nodes about your service.

## Services vs Containers

Docker works at the level of containers. It knows all about individual
containers and their lifecycle. Sidecar works at the level of services and has
the means of mapping containers to service endpoints. It has a lifecycle for
services and it exchanges that information regularly with peers. So we need to
somehow map your containers into services. We don't want to have another
centralized data store to do that. We want this all to be dynamic: new
containers should identify themselves to the system and then just be available.

For Docker systems, Sidecar can get all of the state it needs about your
container from Docker's state and from Docker labels that you apply at
deployment time. This means it works with pretty much all the existing
deployment/scheduler tools in the Docker ecosystem. We've used it with New
Relic's Centurion, with Mesos and Marathon, with Ansible, and with deployments
done via bash scripts.

This is all you need to do to deploy the standard nginx container in a way that
tells Sidecar what to do with it:

{% highlight bash %}
$ docker run -l 'HealthCheck=HttpGet' \
     -l 'ServiceName=awesome-svc' \
     -l 'ServicePort_80=9500' \
     -l 'HealthCheckArgs=http://{% raw %}{{ host }}:{{ tcp 9500 }}{% endraw %}/' \
     -P -d -t nginx
{% endhighlight %}

This will expose the container as a service named `awesome-svc` on all hosts on
port 9500 on the IP bound by haproxy. **Without doing anything else** running
that above command line on a system with Sidecar running will result in a new
port being bound by HAproxy and a new backend with one container in it being
added (once the health check passes).

What we've done is tell Sidecar that the name of the service in this container
will be `awesome-svc`, and that it will expose one port (you can expose N
ports) via the proxy. We're letting Docker auto-assign a public port for us
(with `-P`) so we identify the port by its internal-to-the-container port of
80. Finally we use a little Go template to tell it how to health check the
service. This templating lets us define URLs that will be valid once Docker
binds the container to an IP and port. Sidecar will interpret them at runtime,
after the container has been created and bound.

We now have a one-container service!

## What is with This IP Address Thing?

Your services become known not by their hostname, but by their `ServicePort`.
This is a common pattern in modern distributed systems. You can bind Sidecar
and HAproxy to any address you like. We recommend that you bind it to the same
address everywhere so that the only dynamic thing is that port. From the
standpoint of Docker configuration, you don't need anything other than the bog
standard Docker default network.

The default route on the Docker bridged network is the Docker host. So if we
bind HAproxy on the host itself to an IP that is private to that host, any
container will route it up to the HAproxy. We use `192.168.168.168` because
it's routable out of the Docker bridged network (`127.0.0.0/8` **is not**) and
it's not routed on our network. You might use something else, but the actual
address is irrelevent. If you run the container we build, you can just start
Sidecar in host-network mode and Docker will take care of the rest.

## Taking it One Step Further

Running Sidecar with HAproxy in the same container is great for development, or
for environments where taking a whole node offline at a time might be OK. But
in production we need to leave HAproxy up while Sidecar is getting redeployed,
for example. Or be able to redeploy HAproxy without impacting Sidecar
clustering. So we built [haproxy-api](https://github.com/Nitro/haproxy-api/) as
a companion container to Sidecar that allows you do just that. This is how we
run it in production. It's a robust solution that works well.

But on my laptop, I just `brew install haproxy` and run the `sidecar` binary.
If I'm building a service locally that needs to call out to other dependencies,
I just connect my Sidecar to our development cluster. Then the service that I'm
working on locally can just find its dependencies in the same place it always
does: their well known port.

## There's a Lot More But I'll Stop Now

Hopefully that serves as a soft landing for what this thing does and why you
might want to run it. To see it in action, check out the two Youtube videos I
did showing off Sidecar: [here](https://www.youtube.com/watch?v=VA43yWVUnMA)
and [here](https://www.youtube.com/watch?v=5MQujt36hkI). Also if you want a
little more info about how it works or runs in Docker check out the [main repo
README](https://github.com/newrelic/sidecar/blob/master/README.md) or the
[docker README](https://github.com/newrelic/sidecar/tree/master/docker).
