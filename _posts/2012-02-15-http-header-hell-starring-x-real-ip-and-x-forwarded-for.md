---
layout: post
title: HTTP Header Hell Starring X-Real-IP and X-Forwarded-For
tags: []
status: publish
type: post
published: true
category: articles
meta:
  _edit_last: '1'
  _edit_lock: '1333296912'
  _wp_old_slug: ''
---
It's always fun to spend a whole day debugging something that should be simple.  Actually I think it's always the things that should be simple that end up in a day of debugging. Sharing tales of woe can sometimes help people. Or at least people can laugh at your misery. Here's one such tale.
<h3>Happy Beginnings</h3>
It all starts out like your average fairy tale.  For one of our production apps, we have a setup with a load balancer and some app servers behind it.  In this case the load balancer is HAproxy and the app servers are running Rails with a Sinatra application mounted, all on top of Phusion Passenger on Nginx.  This is a great setup for production systems.
<h3>The Unhappy Middle Bit</h3>
No story that is worth reading has a happy middle, so here's where it went wrong.  The load balancer system needs to handle SSL termination which HAproxy does not support.  HAproxy is, however, a great load balancer through which I have in other jobs run absolutely massive traffic without issue.  It has the benefit of actively monitoring your servers so that it knows they are not responding before some request gets hung up checking for you.  It has great capability for routing traffic based on all kinds of HTTP header information.  Finally, it has a great stats page that gives you a lot of live information about the services it is handling.  We wanted to use HAproxy.

There are a number of solutions for running HAproxy where SSL termination is needed. The best of these is this right at hand. Nginx supports SSL termination, is really lightweight, and is event-based.  It scales to massive proportions without much trouble.  At an unnamed previous employer we were doing 35,000 rpm in production through a single Nginx install.  I know Nginx works fine as a load balancer, but it's nowhere near as nice to run as HAproxy in production.

But... one final requirement, self-imposed for purposes of debugging, was that the app server logs actually contain the original source address of the client.  This now means that the original IP address needs to be relayed from Nginx to HAproxy, to Nginx, to Rails and Sinatra.  The easiest way to do that is to set HTTP headers like <em>X-Forwarded-For</em> or <em>X-Real-IP</em> on the load balancer. <em>X-Forwarded-For</em> is more common and lots of things muck with it.  I thought, to avoid trouble, let's just use <em>X-Real-IP</em> in the SSL terminator's <em>nginx.conf</em>. HAproxy will leave it alone and pass it along to Nginx and Rails/Sinatra on the app servers.  I can have Nginx log it on the app servers and it will be available to put in the <em>production.log</em> as well.

<strong>WRONG</strong>.

This all seemed to work fine in Rails.  Just as expected.  Alas, any attempt to connect to the Sinatra apps mounted on the Rails installation resulted in <em>403</em> and an entire page body consisting of the word "Forbidden".  This was from our Sinatra app as well as from Resque-web.

<strong>First clue:</strong> connecting directly to HAproxy without going through the SSL-terminating Nginx  works as expected.

<strong>Second clue:</strong> a tcpdump of the traffic sent to HAproxy from Nginx shows that both <em>X-Real-IP</em> and <em>X-Forwarded-For</em> are set but only <em>X-Forwarded-For</em> is set by HAproxy.

Poking around with <em>curl</em> and <em>netcat</em> reveals that I only have the problem when both headers are present.  Then after poking at this for awhile I discover that it only doesn't work when they are both set and NOT the same.  What's going on here?  Well Nginx is diligently setting <em>X-Real-IP</em> as expected, but HAproxy is configured to add <em>X-Forwarded-For</em> (leftover from a previous config).  So <em>X-Real-IP</em> is always the real client and <em>X-Forwarded-For</em> is always the IP address of the load balancer.
<h3>The Happy Ending</h3>
So what? There is a gem you perhaps don't know about that is getting invoked in your application stack.  The culprit: <strong>rack-protection</strong>. This gem does a lot of sanity checking and validation on requests headed into a Rack stack. It is included in Rails but something is Rails overrides this particular behavior. Sinatra triggers it, even mounted on top of Rails. Grepping around revealed this test case in <strong>rack-protection</strong>:
<pre lang="ruby">  it 'denies requests where IP and X-Forward-For are spoofed but not X-Real-IP' do
    get('/', {},
      'HTTP_CLIENT_IP'       => '1.2.3.5',
      'HTTP_X_FORWARDED_FOR' => '1.2.3.5',
      'HTTP_X_REAL_IP'       => '1.2.3.4')
    last_response.should_not be_ok
  end</pre>
So this behavior is a, ermm, "feature" of rack-protection.  Knowing is half the battle–or well, all of it.  A quick one-line deletion from the HAproxy config, a new Chef run on the load balancer and we have a working app stack, SSL and all.

You may now either sigh with relief because I've helped you solve the same problem or laugh at my pain. For the therapeutic release of your laughter I do charge a small fee.  Simply post your bank account numbers in the comments section and it will be withdrawn automatically.
