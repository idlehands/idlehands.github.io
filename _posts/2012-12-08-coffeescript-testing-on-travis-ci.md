---
layout: post
title: CoffeeScript Testing on Travis CI
tags: []
status: publish
type: post
published: true
category: articles
meta:
  _edit_last: '1'
  _edit_lock: '1355042480'
---
I have recently been working on 
[Troll-opt](http://github.com/relistan/troll-opt), a powerful but
simple command line parser for Node.js that was inspired by William
Morgan's Trollop gem for Ruby.  I wanted to get CI running and 
[Travis CI](http://travis-ci.org) is a free for open source
service that makes continuous integration fairly painless.  It
wasn't obvious how to get it running with CoffeeScript, though, so
here is what I learned.

I had already set up a `Cakefile` that builds and runs
the tests on my project.  I'm testing with Pivotal's Jasmine, which
is a lot like RSpec and thus very familiar to me, and a darn nice
tool.  In combination with jasmine-node, it works great from the
command line, too.

The `Cakefile` looks like this:
{% highlight coffeescript %}
{spawn} = require 'child_process'
{print} = require 'util'
fs      = require 'fs'

spawnAndRun = (command, args, callback) ->
  subproc = spawn(command, args)
  subproc.stderr.on 'data', (data) ->
  process.stderr.write data.toString()
  subproc.stdout.on 'data', (data) ->
  print data.toString()
  subproc.on 'exit', (code) ->
  callback?() if code is 0

test = (callback) ->
  spawnAndRun 'jasmine-node', ['--coffee', 'spec'], callback

build = (callback) ->
  fs.mkdir 'lib', 0o0755
  print "compiling..."
  spawnAndRun 'coffee', ['--compile', '--output', 'lib', 'src'], callback
  print "\n"

task 'test', 'Run all tests', ->
  test()

task 'build', 'Build the Javascript output', ->
  build()
  
{% endhighlight %}

There's no rocket science there, then.  It just creates a `build`
and a `test` task that make it easy to invoke from Travis CI.  You
could alternatively do this with a custom script, or with commands
directly inserted in the Travis CI configuration (see below).  So,
on to the actual integration.

First, you need your `package.json` file to contain some things it
might not otherwise.  You need all the things you should have
normally, including `devDependencies` to make sure this module can
be built and tested.  But then, I added a `scripts` section which
tells npm and also Travis CI, what to to do test and install this:

{% highlight javascript %}
"devDependencies": { 
    "jasmine-node": ">=1.0.26", 
    "coffee-script": "latest" },
"scripts": {
  "test": "./node_modules/.bin/cake test",
  "install": "./node_modules/.bin/cake build"
},
{% endhighlight %}

The `devDependencies` guarantee that CoffeeScript and Jasmine are
installed. The install script ensures that our code has been compiled
to Javascript and put into the `lib` directory.

Note the paths.  These assume that you are installing your npm
packages locally, hence the `./node_modules/.bin` path which is
where npm puts binaries from installed packages.  The "test" command
will be invoked by npm when you run `npm test`.  This ensures that
Travis knows how to test your application.

Travis CI uses a YAML file to configure it, called `.travis.yml`. 
We need to tell Travis that we are using Node.js so that it doesn't
try to build a Ruby project.  Then, we need to tell it which commands
to run.  In this case, we are going to install the coffee-script
package locally to make sure that cake is in the right path.  The
`before_script` definition will call a script before any tests are
run.  `before_install`, will likewise run before the normal `npm
install` is called on the dependencies in the `package.json`.

{% highlight yaml %}
language: node_js
node_js:
  - 0.8
  - 0.6
before_script:
  ./node_modules/.bin/cake build
before_install:
  - npm install coffee-script
{% endhighlight %}

Be sure to login to Travis and set up your GitHub account and
authorize the commit hook from GitHub to trigger it.  This is a few
simple steps.  Now, when you push to GitHub, your CoffeeScript
should get compiled, and your tests should get run.  Status will
be [reported on Travis](https://travis-ci.org/relistan/troll.opt),
or optionally via an image you link into your `README.md` on GitHub.
