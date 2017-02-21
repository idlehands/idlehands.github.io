---
layout: post
title: ! "Dealing With User Timezones in Postgres"
tags: [postgres, testing, f-timezones]
status: publish
type: post
category: articles
published: true
---

So, somehow you ended up drawing the short straw and have to fix a timezone related bug in the way your team's code pulls data for a user in their timezone. I’ve been there and I’ve got your back.

This post assumes you’re writing all of your data to the db in UTC and having to query for specific times (midnight to midnight in this case) in a different timezone. It doesn’t include code (except PSQL) because this isn’t a language specific pain in the ass.

Start with setting up good test data
------------------------------------

I’ll get the the weird part of the query, but first let’s set up some test data to make sure our query is working correctly. I will assume you know how to make data in your test db, and for now, we are going to use inserted\_at as the timestamp that the data was created. In our use case, we’ll treat that as the column being queried against.

You want to pick a day in your test user’s timezone and figure out what those start and end datetimes look like in UTC. Populate some data in the db one second into that day with normal looking values for your application. Then, popluate a row one second before the end of that day with normal looking data. If you want stuff in between, go for it. You’ll know better than I whether or not that makes sense for you.

Now let’s set up BAD dats. Subtract a second from the start time of that day and add a second to the end time. At each of those times, insert data with crazy high values. This serves two purposes: if you’re debugging and see high values, you know you’re code/query is still having issues pulling in the right time zone b) if your test rely on a delta, you’ve made sure that grabbing the bad data will pull you outside of that delta.

---I will insert a beautiful timeline here in the next day or so---

In our example, our user’s timezone is 6 hours behind UTC. So we will insert bad data at 2016-12-21 05:59:59 UTC and 2016-12-22 06:00:01 UTC. We will insert whatever good data we want between 2016-12-21 06:00:01 UTC and 2016-12-22 05:59:59 UTC. I’ve moved and *entire *second into that day because there are no consequences for doing so and it’s easier than dealing with parts of a second.

The query
---------

The key to pulling this data is telling postgres to pull the data in UTC for a time zone that you pulled from another table. This allows you to make a single query, and give you the flexibility to build a significantly more complex one. I’m going to keep it simple here, though, just pulling for one user. You’ll get the main part of what you need and you can build from there.

{% highlight sql %}
SELECT SUM(att.head_count)
FROM attendence att
JOIN users u
ON att.user_id = u.id
WHERE att.inserted_at
BETWEEN ('2016-12-21 00:00:00.000' AT TIME ZONE 'UTC' AT TIME ZONE u.timezone)
  AND
        ('2016-12-21 23:59:59.999' AT TIME ZONE 'UTC' AT TIME ZONE u.timezone)
AND u.id = 1;
{% endhighlight %}

Sorry about the formatting, but I wanted it to fit in single lines in the format of this blog.`('2016-12-21 00:00:00.000' AT TIME ZONE 'UTC' AT TIME ZONE u.timezone)` is the funky sql that will get you want you need. It give you midnight in your user’s timezone. Run your tests if you don’t believe me. It’s the real deal. I typically add a comment above the query that says `# This odd sql converts UTC to user's timezone. DON'T CHANGE`. I do that because it’s hard to read and understand and people really seem to want to remove it.

In Summary
----------

Test your timezone code in a way that you know it is working correctly. Make the db do the heavy lifting. Comment below if you have a better way.

Cheers.