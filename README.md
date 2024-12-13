# Interior

**Note**: This is an experiment at the moment.

Interior is a lightweight library to assist with restricting access to certain modules in an Elixir project.
You can think of it a bit like boundary but with a block list approach and way less features.

Use-cases:

- Disallow usage of some modules under a particular namespace to be used outside of it. E.g forbid calling `Foo.Bar.x()` outside of the `Bar` namespace.

## Comparison to boundary

- Interior uses a block list approach; a developer needs to tell interior what is NOT allowed. Boundary needs to be told what to allow. This should make interior easier to integrate into an existing large code base as it allows everything by default.
- Interior can do way less than boundary, e.g restrict access to external dependencies etc.
- Interior's implementation is currently a stripped down, a bit hacky copy of boundary as PoC

## TODO

* [ ] Be able to configure if Interior violations should be compiler warnings or just logged

## Usage

Add the interior dependency, and add it as a compiler.

```elixir
defmodule MySystem.MixProject do
  use Mix.Project

  # ...

  def project do
    [
      compilers: [:interior, ...] ++ Mix.compilers(),
      # ...
    ]
  end

  # ...

  defp deps do
    [
      {:interior, "~> 0.1", runtime: false},
      # ...
    ]
  end

  # ...
end
```

Now we can use inerior to restrict access to some modules. The following configuration will:

1. Forbid any calls to MySystemWeb.* modules and functions, except for MySystemWeb.Endpoint, from outside of the MySystemWeb namespace.
2. Forbid any calls to MySystem.Blog.Internal.* modules and functions from outside of the MySystem.Blog namespace.

```elixir
defmodule MySystemWeb do
  use Interior, restricts: [{:all, except: [Endpoint]}]
  # ...
end

defmodule MySystem.Blog do
  use Interior, restricts: [Internal]
  # ...
end
```

See the `example_projects` dir for complete examples.
