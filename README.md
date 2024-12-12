# Interior

Interior is a light weight library to assist with restricting access to certain modules in Elixir project.
You can think of it like boundary but takes a block list approach.

Use-cases:

- Disallow usage of some modules under a particular namespace to be used outside of it. E.g forbid calling `Foo.Bar.x()` outside of the `Bar` namespace.

## Comparison to boundary

Interior was born after using boundary and really liking what it can do but seeing some issues when introducing it into big, existing code bases.

- Interior uses a block list approach; a developer needs to tell interior what is not allowed. Boundary needs to be told what to allow. This should make interior easier to integrate into an existing large code base as it allows everything by default.
- Interior violations can be configured to either cause a compilation error, a warning or just log
- Interior uses a lof of the same internal ideas/implementation
- Interior can do way less than boundary, e.g restrict access to external dependencies

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
  use Interior, restrict: {:all, :except: Endpoint}
  # ...
end

defmodule MySystem.Blog do
  use Interior, restrict: [Internal]
  # ...
end
```
