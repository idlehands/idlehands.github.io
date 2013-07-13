---
layout: post
title: Discovering Pending Rails Migrations With Git
tags: []
status: publish
type: post
published: true
category: articles
meta:
  _edit_last: '1'
  _edit_lock: '1346313616'
  _wp_old_slug: ''
---
At [MyDrive](http://mydrivesolutions.com/),
[Gavin](https://twitter.com/#!/gavinheavyside) and I came up with
what I think is a pretty novel solution to discovering new Rails
migrations at deployment time. We deploy often but not on every
commit.  We usually know about new migrations from reading the
commits—but no one is perfect and sometimes you miss a commit or
three. The standard checks for pending migrations involve deploying
the new code and verifying the schema version against the database
before reloading the app. This works but it's slow and you don't
find out about the migrations until the code has been pushed to at
least one system. Automating this is still a good idea. But it's
often nice to find out about pending migrations right up front. 
Sometimes you just don't want to deploy right now if there are
pending migrations.

But, do we need to talk to the DB to find this out? Doesn't git
tell us what has changed in our code? Why yes, it does.

We tag each deployed ref with a git tag representing the deployment
environment (Capistrano stage) and the time and date. This is tells
us what code was running in any environment at any time. We now
also have a moving git tag that identifies the last deployment to
any environment. After each deployment we move the tag to the current
`HEAD` ref. Finding new migrations is now as simple as
`git diff` on the `db/migrate` tree against
the previous deployment tag for this environment. Capistrano does
this as part of the deployment and lets us choose to abort if we
don't want to deploy with migrations. It's not perfect: it will
generate false positives on any change to any file in the migrations
tree, but old migrations are rarely changed. Here's what it looks
like:

{% highlight ruby %}
sleipnir:api karl$ cap production deploy
* 15:00:36 == Currently executing `production`
triggering start callbacks for `deploy`
* 15:00:36 == Currently executing `multistage:ensure`
* 15:00:36 == Currently executing `deploy`
triggering before callbacks for `deploy`
*** Deploying HEAD from branch 'master' to 'production'
*** Pending migrations!!!
create mode 100644 db/migrate/20120327113515_store_info_in_alerts.rb
create mode 100644 db/migrate/20120327190626_add_pending_data_table.rb
create mode 100644 db/migrate/20120329102140_populate_pending_data_table.rb
Do you want to continue deployment? (Y/N)
n
*** Aborting deployment!
{% endhighlight %}

Notably this needs to be done from a clean tree because you will
be changing git tags on the local installation. So it should either
be done from a deployment host or from a clean checkout of your
code. It's best to detect this in your deployment scripts as well
so that you don't get into trouble. If there is interest, we could
probably release this as a Capistrano plugin. If you decide to
implement it yourself, here are some [notes on helpful git
commands](https://gist.github.com/2262674) for doing so.

**Update: I have released two gems to do this for you.**
The first is called [capistrano-deploytags](http://goo.gl/av9tE)
and handles all of the tagging for you at deployment time.  The
second, [capistrano-detect-migrations](http://goo.gl/ICDwm) does
what I described above.  It requires the functionality from
[capistrano-deploytags](http://goo.gl/av9tE).
