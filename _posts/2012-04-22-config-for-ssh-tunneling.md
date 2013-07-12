---
layout: post
title: A Works-Anywhere Config For SSH Tunneling
tags: []
status: publish
type: post
published: true
category: articles
meta:
  _edit_last: '1'
  _edit_lock: '1335106299'
---

**TL;DR:** This article proposes a simple solution to DNS
and jump hosts that allows you to use short names on the ssh
command line without impacting accessing external servers.

This is not a new topic but I think this is a novel way of handling
it. I've had a number of solutions for SSH'ing through a jump host
over the years. Some have worked better than others.  I recently
built a setup that seems to work very well and that I am happy with
so I thought it was worth sharing.

Generally you have a jump box if you have a remote network of
isolated hosts and you want to have a security pinch point on inbound
SSH sessions.  You generally fortify the jump host as a bastion
host and only allow SSH sessions on the remote internal network
when they are inbound from the jump box. This is a fairly common
architecture and I've seen it at a score of companies. 

What becomes a pain is initiating two ssh sessions every time you
want to get to a host inside the remote network, or if you want to
scp a file, you end up copying it twice.  So people often set up
scripts for getting around this and connecting directly to the
remote internal host over some kind of SSH tunnel.  Now you either
need a config entry for each host, or a remote domain name that you
can use to wildcard a &lt;code&gt;Host&lt;/code&gt; entry in your
SSH config.  But then you are not just typing the hostname each
time you connect, you are also typing the domain name.  It's annoying.

What I've set up is, I think, much better.  It connects a backgrounded
tunnel to the jump host, running a SOCKS proxy.  All future connections
are then tested to see if they would work directly, and if so they
are connected.  Otherwise they are proxied over the SOCKS tunnel
to the jump host.  It's simple, and having used it in production
now for awhile, it seems to work pretty well.  I don't have to use
the domain name for the host on the other side of the tunnel, and
I don't have to manage ssh config records.  Here's the only entry
you need in your SSH config:

{% gist 2159451 ssh-config %}

You'll want to replace `username` and `jumphost` with your actual
remote username and jump host name.  You may also want an SSH config
entry for that host to make sure it uses your RSA key for authentication.
And here is the script that runs it all, to be installed in
`~bin/ssh-proxy.sh`:

{% gist 2159451 ssh-proxy.sh %}

Enjoy!
