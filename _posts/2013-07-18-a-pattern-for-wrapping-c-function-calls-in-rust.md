---
layout: post
title: ! "A Pattern for Wrapping C Function Calls in Rust"
tags: [rust, development]
status: publish
type: post
category: articles
published: true
---
In my [recent project](/a-week-with-mozilla-rust), I found an idiom that seems pretty useful for instantiating new objects that wrap the functionality of an external C function. I don't propose that I'm breaking new ground with this pattern, but something about it felt fairly elegant and worth sharing. 

I was experimenting with a library of hashing functions that are imported from OpenSSL. These are then wrapped up by some Rust code to make them seamless for use elsewhere in Rust. That wrapper code takes the form of a `struct` that has an `impl` with one class method and two instance methods.

The struct itself defines two pieces of information we need to know about the call into the C code and stores a pointer to an `extern "C" unsafe` function. At instantiation time we have to pass the `engine` value in from outside.

{% highlight ruby %}
struct HashEngine {
  engine:      (extern "C" unsafe fn(*u8, c_uint, *u8) -> *u8),
  digest_size: uint,
  block_size:  uint
}
{% endhighlight %}

That's reasonably standard dependency injection, but we want to do it in a way that doesn't require manually creating one of these things every time.  We don't want to have to say

{% highlight ruby %}
let hash_engine = ~HashEngine{ engine: crypto::MD5, digest_size: 16, block_size: 64  }
{% endhighlight %}

That just requires knowing way too much about the way the internals will work. So we have a `new` class method that creates one of these pre-configured. Since `new` is nothing special in Rust, we just use that by convention as a factory class  method. I wanted it to take one parameter, to tell the method which configuration of `HashEngine` to return. So I created an `enum` specifying all of the configurations:

{% highlight ruby %}
enum HashMethod { MD5, SHA1, SHA224, SHA256, SHA384, SHA512 }
{% endhighlight %}

The `impl` for the `HashEngine` `struct` then looks like this:
{% highlight ruby %}
impl HashEngine {
  fn new(engine: HashMethod) -> ~HashEngine {
    match engine {
      MD5    => ~HashEngine{ engine: crypto::MD5,    digest_size: 16, block_size: 64  },
      SHA1   => ~HashEngine{ engine: crypto::SHA1,   digest_size: 20, block_size: 64  },
      SHA224 => ~HashEngine{ engine: crypto::SHA224, digest_size: 28, block_size: 64  },
      SHA256 => ~HashEngine{ engine: crypto::SHA256, digest_size: 32, block_size: 64  },
      SHA384 => ~HashEngine{ engine: crypto::SHA384, digest_size: 48, block_size: 64  },
      SHA512 => ~HashEngine{ engine: crypto::SHA512, digest_size: 64, block_size: 128 }
    }
  }

  fn hash(&self, data: ~[u8]) -> ~Digest {
    let hash_func = self.engine;
    Digest::new(
      unsafe {
        vec::from_buf(
          hash_func(
            vec::raw::to_ptr(data),
            data.len() as c_uint, ptr::null()
          ),
          self.digest_size
        )
      }
    )
  }
}
{% endhighlight %}

Notice how the `new` method is matching the `enum` value passed in to decide how to configure the returned object. Now we don't have to know anything about the block size and digest size of SHA384 to create a HashEngine that wraps it up for our use.

It's simple to get and use a new instance.

{% highlight ruby %}
let engine = HashEngine::new(SHA1);
engine.hash(~"something to hash");
{% endhighlight %}

The other nice thing that happens here is that the `hash` method now does all the annoying work of wrapping up all those external C functions into a Rust call that does the right thing. We can do it in one place, in a re-usable and generic manner, and any configuration of `HashEngine` is supported.

The compiler helps us out here, too. By using an `enum` to define the configuration, it can notify us at compile time if any other library code calling this method is passing an invalid value.

It's worth pointing out that the `hash` function returns a `Digest` struct using its `new` method as well.

If you take a look at the [original code on GitHub](https://github.com/relistan/cryptorust/), you will see that a native HMAC is implemented in Rust as another method on this `struct` (not shown for simplicity above).

Summary
-------
What I think is most useful about this pattern is that it provides a nice way to wrap up interchangeable C methods in a nice clean Rust interface, hides all of the C oddity and conversion, and is very extensible.

I'm new to Rust and there could be a more elegant solution to this. But this is what I came up with, and from checking around GitHub to see what other people have done, I think it's fairly novel.
