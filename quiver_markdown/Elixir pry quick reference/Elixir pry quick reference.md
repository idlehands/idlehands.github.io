This post assumes you have experience using interactive debuggers in other languages, and want to use pry in Elixir. First off, how great is it that we have an interactive debugger built right into the language? Very great, I say. Coming from Ruby, pry is a well-known tool. Things are a little different in Elixir, so I put this together to help people have a reference until they remember these things or hide them behind aliases.

One thing that is super important to note is that when running pry, you are in a IEx process and not inside of wherever you dropped your debugger line. So, while you have access to data local to the function you entered pry from, you DO NOT have access to anything private in the module. That means you can’t run functions defined with `defp` and you don’t have access to @attributes.

* The workarounds for this are to temporarily make your private functions public for debugging (make sure you change them back!)
* Create local variable with the same values of your @attributes if you need them.

Calling pry
-----------

You’ll need to require IEx (note the capitalization) and then invoke pry where you need to debug.

```elixir
defmodule Bob do
  require IEx
  
  @information_from_config  Application.get_env(:my_app, :that_thing_from_config)
  
  def last_name do
    IEx.pry
    do_last_name
  end
  defp do_last_name do
    "Robertson"
  end
end
```

kick it off:

```elixir
# run your project via Mix
$ iex -S mix
Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false]

Compiling 2 files (.ex)
Generated prying app
Interactive Elixir (1.3.4) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Bob.last_name

Request to pry #PID<0.124.0> at lib/prying/bob.ex:7


      def last_name do
        IEx.pry
        do_last_name
      end

Allow? [Yn] Y

Interactive Elixir (1.3.4) - press Ctrl+C to exit (type h() ENTER for help)
pry(1)> #start debugging
```

Using pry in tests
------------------

You’ll need to invoke your tests via iex from the command line.

When you are running tests, there is a default timeout where it assumes a process that’s stopped is dead. You’ll need to add the flag `—trace` prevent timeout issues.

```elixir
$ iex -S mix test --trace
# this will prevent this:
  1) test lists all active entries on index (BookBot.BookControllerTest)
     test/controllers/book_controller_test.exs:12
     ** (ExUnit.TimeoutError) test timed out after 60000ms. You can change the timeout:
```

Stop debugging and let your code run
------------------------------------

Simply type `respawn`. That will kill the iex process and spin a new one up at that same place in the code. From the outside, it will look like you just resumed running your code. Note that IEx.pry does NOT have a `disable-pry` function like Ruby’s pry.

Using pry with tests using Ecto (the database package in Phoenix)
-----------------------------------------------------------------

If you’re working in a phoenix project, there is a good chance you’re going to see this:

```elixir
Interactive Elixir (1.3.4) - press Ctrl+C to exit (type h() ENTER for help)
pry(1)> 15:07:59.029 [error] Postgrex.Protocol (#PID<0.399.0>) disconnected: ** (DBConnection.ConnectionError) owner #PID<0.470.0> timed out because it owned the connection for longer than 15000ms
```

This is because your tests are run as separate processes each with their own db connection to allow parallel test runs. To address this, add a ownership\_timeout to your config/test.exs:

```elixir
 13 config :some_app, SomeApp.Repo,
 14   adapter: Ecto.Adapters.Postgres,
 15   username: "your_name",
 16   password: "some_password",
 17   database: "some_app_test",
 18   hostname: "localhost",
 19   pool: Ecto.Adapters.SQL.Sandbox,
 20   ownership_timeout: 60_000_000
```

Don’t forget to add it to your dev environment if you need it there, too.

More Phoenix stuff
------------------

I found a pretty good run-down on using pry in the various parts of Phoenix by Brandon Richey. It should give you a good start.