---
layout: post
title: Convert Chef Cookbooks to Puppet Modules
tags:
- Chef Puppet Ruby DevOps
status: publish
type: post
published: true
category: articles
meta:
  _edit_last: '1'
  _edit_lock: '1333355883'
  _wp_old_slug: ''
---
What if you, for any number of reasons, needed to convert Chef
cookbooks to Puppet modules and it were convenient to do it in an
automated way? How hard the task would be to convert the cookbook
depends largely on how off the ranch the recipes are with respect
to the Chef DSL.  Since Chef recipes are just Ruby code, you can
write whatever you want into the recipe.  But if the recipes were
written in a way that mostly sticks with the Chef DSL you can get
fairly clean Puppet output in a really simple way: take advantage
of the fact that Chef's DSL is Ruby, and write a  system for
evaluating the Chef DSL and generating Puppet syntax output.  I
found this to be a surprisingly legitimate case for heavy
meta-programming as much of the Chef DSL translates pretty well
directly to Puppet.

Hopefully no one is ready to start a flame war at this point.  I
am not suggesting that anyone use one system or the other.  I
recently had the need to convert a lot of site-specific Chef code
to Puppet <a href="http://github.com/relistan/chef2puppet">so I
wrote a tool </a>to save me a lot of time.  The general approach
is to convert as much of the Chef code to a module formatted for
use in Puppet as possible.  You will need to edit the module when
it is done being converted.  Chef makes an assumption about the
relationship between resources based on order.  Puppet does no such
thing.  So you will likely need to managed the dependencies yourself. 
However, if you specified them explicitly in Chef, they will work
in Puppet out of the box in most cases. There are currently only
three options you need to specify to run the tool:

{% highlight bash %}
Usage: convert.rb [options]
-c, --cookbook COOKBOOK          Chef Cookbook directory (e.g. contains /recipes, /attributes...)
-o, --output-dir OUTPUT_DIR      Output directory (where modules are written)
-s, --server-name SERVER_NAME    The name of the Puppet server to be used in puppet:// URLs</pre>
{% endhighlight %}

Here is what the converter handles:

* Converts cookbooks to a Puppet module directory structureg
* Converts recipes to mostly-right Puppet manifests in the proper locationg
* Copies templates to the correct location in the Puppet moduleg
* Downloads remote_file resources into the Puppet module's files directoryg
* Tries to replace Chef's node[:some][:var] variables with $some_var formatg
* Edits templates to replace variable substitutions with the same formatg
* Makes an attempt to replace not_if and only_if blocks with Puppet equivalentsg

I am still working with the tool and it will probably evolve over time.  But it has a pretty good success rate now.  Here's some sample output:

{% highlight bash %}
$ ./convert.rb -c /tmp/chef-cookbooks/cookbooks/xen/ -o /tmp/asdf -s localhost.localdomain
Cookbook Name:   xen
Recipes Path:    /tmp/chef-cookbooks/cookbooks/xen/recipes
Templates Path:  /tmp/chef-cookbooks/cookbooks/xen/templates/default
Files Path:      /tmp/chef-cookbooks/cookbooks/xen/files/default
Output Path:     /tmp/asdf/xen
Working on recipe... /tmp/chef-cookbooks/cookbooks/xen/recipes/default.rb
Working on recipe... /tmp/chef-cookbooks/cookbooks/xen/recipes/dom0.rb
Fetching /xen/xen-Config.mk from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/xen-Config.mk...
Fetching /xen/linux-2.6.31.12.tar.bz2 from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/linux-2.6.31.12.tar.bz2...
Fetching /xen/patch-kernel.sh from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/patch-kernel.sh...
Fetching /xen/xen-3.4-testing.tar.bz2 from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/xen-3.4-testing.tar.bz2...
Fetching /xen/xen-patches-2.6.31-12.tar.bz2 from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/xen-patches-2.6.31-12.tar.bz2...
Fetching /xen/make-initrd.sh from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/make-initrd.sh...
Fetching /xen/initramfs_conf.tar.bz2 from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/initramfs_conf.tar.bz2...
Fetching /xen/07_xen from some-bucket.s3.amazonaws.com to /tmp/asdf/xen/files/07_xen...
Modifying template /tmp/chef-cookbooks/cookbooks/xen/templates/default/xen-kernel-config.erb...
{% endhighlight %}

**Code:** (Find it on GitHub)[http://github.com/relistan/chef2puppet]
