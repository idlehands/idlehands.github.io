---
layout: post
title: ! "A Week with Mozilla's Rust"
tags: []
status: publish
type: post
category: articles
published: true
---
I want another systems language in my tool belt. I want a language where can be much more productive than in C: one in which I do not fear the correctness of my memory management, and don't have to go through major gyrations to write concurrent code. But as I want a systems language, something that can effectively replace C that means anything with enforced garbage collection like Go is out. Go is also not particularly friendly to interface to external libraries written in C. C++ has all of the pitfalls of C memory management and does not improve the concurrency situation at all.  There are a few contenders still standing at that point, but I'll look at one of them here.

Mozilla's [Rust](http://rust-lang.org/) might be the solution. Rust's big wins are a modern object system, closures, a concurrency system designed for multi-core systems, and a memory model where the compiler can tell you if you're doing something wrong or unsafe at compile time. Rust is also ABI compatible with C which makes tying libraries written in Rust into external code a minimal effort. Even less effort is required when tying C libs to Rust.  If you want garbage collection, you can have it and you are fully in control of which memory is managed in this way.  Wins all around.

I spent a week working with Rust to get a better understanding of what it can and can't do, and what I might be able to use it for. What I found is a really appealing language with a lot of great thinking behind it. But it is heavily in flux at the moment, as its *0.7* release number indicates.  I wrote some code in 0.6 just before the 0.7 release arrived. I then spent the better part of an evening migrating my couple of hundred lines of code. And the current pace of revisions is likely to continue for a few releases: more breaking changes are in the works for 0.8. However, all this churn does seem to represent advancement and refinement in the language and compiler so it's not for nothing. I understand that a 1.0 release is slated for the latter part of the year.

As the community around any language is as important as the language, I wondered how Rust would fare. What I've found so far is a friendly group of very competent people who were perfectly happy to assist me on IRC when I fell afoul of the documentation and my ability to read the compiler code. The compiler is itself written mostly in Rust now.  Mozilla already sits squarely at the center of a fairly robust community and it seems that Rust is benefitting from that strength. I have yet to see fewer than 200 people on the IRC channel, and `/r/rust` on Reddit is fairly active.

My summary on the state of things is that they are too much in flux for anything like production code at the moment. But I don't think it will be that long before that situation is reversed.  I expect major work will be happening in Rust by this time next year as the language settles down and major libraries can start to be written.

That's how I see the state of all things Ruat. But, I'd like to show some of the niceties of Rust so let's take a look at some of my code. **Full disclaimer:** I don't claim that any of this code is either correct or idiomatic Rust. It is solely my best effort. Feedback is of course welcome.

###Some Code
*You can take a look at the whole project [on GitHub](https://github.com/relistan/cryptorust)*

My experiment was to wrap some of the hashing functions from OpenSSL and to implement HMAC in Rust natively. This seemed to be a low enough level exercise to test Rust's chops as a systems programming language while also getting a sense of how it feels to write native Rust code. I found that I really like the language and that generally when I wanted to reach for something it was there. When it wasn't, I had only to make a few adjustments to my thinking and there was a nice set of tools waiting at hand.

####FFI
Linking C libraries to your Rust code is dead simple if you just need to access some C functions. You simply define the method sigantures with types that Rust can understand and give it a hint about linking the required shared library (if any). Here is the complete code for wrapping some C hashing methods with Rust's Foreign Function Interface (FFI). Note that this is 0.7 code.

{% highlight ruby %}
mod crypto {
  use std::libc::c_uint;
#[link_args = "-lcrypto"]
  extern { 
    fn SHA1(src: *u8, sz: c_uint, out: *u8) -> *u8;
    fn MD5(src: *u8, sz: c_uint, out: *u8) -> *u8;
    fn SHA224(src: *u8, sz: c_uint, out: *u8) -> *u8;
    fn SHA256(src: *u8, sz: c_uint, out: *u8) -> *u8;
    fn SHA384(src: *u8, sz: c_uint, out: *u8) -> *u8;
    fn SHA512(src: *u8, sz: c_uint, out: *u8) -> *u8;
  }
}
{% endhighlight %}

You can now access those methods as if they were written in Rust itself. 

Things get more complicated if you need to pass data structures into the C code. But it's not horrible due to the fact that Rust's `struct`s are interchangeable with C. You define your data structure in Rust and then pass it to the C functions just as you would natively. Other situations like allocating blocks of memory to pass in are catered to with the standard `vec` module.

####Object System
The object system is modern and very nice to use. Objects are effectively structs with code associated with them. You define a `struct` and then, in a separate `impl` block, you write the code that will make up the class and instance methods. Here is one simple type I used for returning digests from hashing functions:

{% highlight ruby %}
struct Digest { digest: ~[u8] }

impl Digest {
  fn new(digest: ~[u8]) -> ~Digest { return ~Digest{ digest: digest } }

  fn hexdigest(&self) -> ~str {
    let mut acc = ~"";
    for self.digest.iter().advance |&byte| { acc = acc.append(fmt!("%02x", byte as uint)); }
    acc
  }
}
{% endhighlight %}

There is effectively one class method here and one instance method. The `hexdigest` method requires that the first argument be a reference to an object of type Digest. Much like in Python, this is passed for you when the method is invoked on the object. But it is a signal to the compiler that this is an instance method not a class method. 

*Side note:* If you're wondering why I didn't write something like `acc += fmt(!...)` that is because in 0.7 `+=` is currently removed for `str` objects. This is slated to return in 0.8.

The `new` method on the other hand takes no `&self` argument. It is like a class method. One thing that is not obvious here, is that you can re-open classes at any time with a new `impl` block and add new code. This idiom is often used in Ruby and other dynamic languages when working with external libraries and I think this functionality will serve Rust well. It is rather unique for a compiled language.

Using the `Digest` object looks like this:

{% highlight ruby %}
let digest = Digest::new(_some_binary_);
println(fmt!("%s", digest.hexdigest()));
{% endhighlight %}

###Closures
We also see a closure in the code above. Coming from Ruby, these feel really nice in Rust as they are by appearances quite similar. I won't get into a long explanation about iterators here (they are in flux), but the `advance` method takes a closure.  We then modify the mutable `acc` variable on each iteration as the closure has this variable in scope.  Nice.

###Pattern Matching
Something not yet mentioned is the pattern matching system in Rust. This is similar to that in Erlang and other languages and lends some really flexible syntax to certain statements. A short example of pattern matching (albeit not the best example) from my project was this:

{% highlight ruby %}
let computed_key = match key.len() {
  _ if key.len() > self.block_size => self.zero_pad(self.hash(key).digest),
  _ if key.len() < self.block_size => self.zero_pad(key),
  _ => key
};
{% endhighlight %}

The `match` block does a pattern match on key.len() in this case. The following lines then define matches which might fit. The underscore is a universal match, and if you look at this carefully it appears that all lines will match. However, the `if` statements following the pattern are guards that must be true in order for the pattern to match.

This is a slight abuse of `match`, using it much more like a `switch` statement. It keeps the code clean and compact though. And one of the nice things about pattern matching is that the compiler will analyze the block to the best of its ability and error if there is a case for which you have not supplied a pattern. Had we left the final `_ => key` off the pattern, this would not have compiled. More helpful validation at compile time to save us from errors at run time.

###More to Come

I put up all the code [on GitHub](https://github.com/relistan/cryptorust) for review. I will not claim that this is correct or idiomatic Rust code, but it may serve to show off some of the things you can do in Rust. I will continue to contribute to the Rust community as it develops.