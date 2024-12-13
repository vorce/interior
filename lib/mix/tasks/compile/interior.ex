defmodule Mix.Tasks.Compile.Interior do
  @moduledoc false

  alias Interior.Mix.Xref

  def run(argv) do
    {opts, _rest, _errors} = OptionParser.parse(argv, strict: [force: :boolean, warnings_as_errors: :boolean])
    Xref.start_link(Keyword.take(opts, [:force]))

    Mix.Task.Compiler.after_compiler(:elixir, &after_elixir_compiler/1)
    Mix.Task.Compiler.after_compiler(:app, &after_app_compiler(&1, opts))

    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [__MODULE__ | tracers])

    {:ok, []}
  end

  @doc false
  def trace({remote, meta, to_module, _name, _arity}, env)
      when remote in ~w/remote_function imported_function remote_macro imported_macro/a do
    mode = if is_nil(env.function) or remote in ~w/remote_macro imported_macro/a, do: :compile, else: :runtime
    record(to_module, meta, env, mode, :call)
  end

  def trace({local, _meta, _to_module, _name, _arity}, env)
      when local in ~w/local_function local_macro/a,
      # We need to initialize module although we're not going to record the call, to correctly remove previously
      # recorded entries when the module is recompiled.
      do: initialize_module(env.module)

  def trace({:struct_expansion, meta, to_module, _keys}, env),
    do: record(to_module, meta, env, :compile, :struct_expansion)

  def trace({:alias_reference, meta, to_module}, env) do
    unless env.function == {:interior, 1} do
      mode = if is_nil(env.function), do: :compile, else: :runtime
      record(to_module, meta, env, mode, :alias_reference)
    end

    :ok
  end

  def trace(_event, _env), do: :ok

  defp record(to_module, meta, env, mode, type) do
    # We need to initialize module even if we're not going to record the call, to correctly remove previously
    # recorded entries when the module is recompiled.
    initialize_module(env.module)

    unless env.module in [nil, to_module] or system_module?(to_module) or
             not String.starts_with?(Atom.to_string(to_module), "Elixir.") do
      Xref.record(
        env.module,
        %{
          from_function: env.function,
          to: to_module,
          mode: mode,
          type: type,
          file: Path.relative_to_cwd(env.file),
          line: Keyword.get(meta, :line, env.line)
        }
      )
    end

    :ok
  end

  defp initialize_module(module),
    do: unless(is_nil(module), do: Xref.initialize_module(module))

  # Building the list of "system modules", which we'll exclude from the traced data, to reduce the collected data and
  # processing time.
  system_apps = ~w/elixir stdlib kernel/a

  system_apps
  |> Stream.each(&Application.load/1)
  |> Stream.flat_map(&Application.spec(&1, :modules))
  # We'll also include so called preloaded modules (e.g. `:erlang`, `:init`), which are not a part of any app.
  |> Stream.concat(:erlang.pre_loaded())
  |> Enum.each(fn module -> defp system_module?(unquote(module)), do: true end)

  defp system_module?(_module), do: false

  defp after_elixir_compiler(outcome) do
    # Unloading the tracer after Elixir compiler, irrespective of the outcome. This ensures that the tracer is correctly
    # unloaded even if the compilation fails.
    tracers = Enum.reject(Code.get_compiler_option(:tracers), &(&1 == __MODULE__))
    Code.put_compiler_option(:tracers, tracers)
    outcome
  end

  defp after_app_compiler(outcome, opts) do
    # Perform the interior checks only on a successfully compiled app, to avoid false positives.
    with {status, diagnostics} when status in [:ok, :noop] <- outcome do
      # We're reloading the app to make sure we have the latest version. This fixes potential stale state in ElixirLS.
      Application.unload(Interior.Mix.app_name())
      Application.load(Interior.Mix.app_name())

      Xref.flush(Application.spec(Interior.Mix.app_name(), :modules) || [])

      # Caching of the built view for non-user apps. A user app is the main app of the project, and all local deps
      # (in-umbrella and path deps). All other apps are library dependencies, and we're caching the interior view of such
      # apps, because that view isn't changing, and we want to avoid loading modules of those apps on every compilation,
      # since that's very slow.
      user_apps =
        for {app, [_ | _] = opts} <- Keyword.get(Mix.Project.config(), :deps, []),
            Enum.any?(opts, &(&1 == {:in_umbrella, true} or match?({:path, _}, &1))),
            into: MapSet.new([Interior.Mix.app_name()]),
            do: app

      view =
        with false <- Keyword.get(opts, :force, false),
             view when not is_nil(view) <- Interior.Mix.read_manifest("interior_view"),
             do: view,
             else: (_ -> rebuild_view())

      stored_view =
        Enum.reduce(user_apps, %{view | unclassified_modules: MapSet.new()}, &Interior.View.drop_app(&2, &1))

      Interior.Mix.write_manifest("interior_view", stored_view)

      errors = check(view, Xref.entries())
      print_diagnostic_errors(errors)
      {status(errors, opts), diagnostics ++ errors}
    end
  end

  defp rebuild_view do
    Interior.Mix.load_app()
    Interior.View.build(Interior.Mix.app_name())
  end

  defp status([], _), do: :ok
  defp status([_ | _], opts), do: if(Keyword.get(opts, :warnings_as_errors, false), do: :error, else: :ok)

  defp print_diagnostic_errors(errors) do
    if errors != [], do: Mix.shell().info("")
    Enum.each(errors, &print_diagnostic_error/1)
  end

  defp print_diagnostic_error(error) do
    Mix.shell().info([severity(error.severity), error.message, location(error)])
  end

  defp location(error) do
    if error.file != nil and error.file != "" do
      line = with tuple when is_tuple(tuple) <- error.position, do: elem(tuple, 0)
      pos = if line != nil, do: ":#{line}", else: ""
      "\n  #{error.file}#{pos}\n"
    else
      "\n"
    end
  end

  defp severity(severity), do: [:bright, color(severity), "#{severity}: ", :reset]
  defp color(:error), do: :red
  defp color(:warning), do: :yellow

  defp check(application, entries) do
    Interior.errors(application, entries)
    #|> IO.inspect(label: "errors")
    |> Stream.map(&to_diagnostic_error/1)
    |> Enum.sort_by(&{&1.file, &1.position})
  rescue
    e in Interior.Error ->
      [diagnostic(e.message, file: e.file, position: e.line)]
  end

  defp to_diagnostic_error({:invalid_reference, error}) do
    reason =
      case error.type do
        :forbidden ->
          "(#{inspect(error.reference.to)} is restricted by #{inspect(error.interior.name)})"
      end

    {func, arity} = error.reference.from_function
    message = "forbidden reference to #{inspect(error.reference.to)} in #{inspect(error.from_module)}.#{func}/#{arity}\n  #{reason}"

    diagnostic(message, file: Path.relative_to_cwd(error.reference.file), position: error.reference.line)
  end

  def diagnostic(message, opts \\ []) do
    diagnostic =
      %Mix.Task.Compiler.Diagnostic{
        compiler_name: "interior",
        details: nil,
        file: nil,
        message: message,
        position: 0,
        severity: :warning
      }
      |> Map.merge(Map.new(opts))

    cond do
      diagnostic.file == nil ->
        %{diagnostic | file: "unknown"}

      diagnostic.position == 0 and File.exists?(diagnostic.file) ->
        num_lines =
          diagnostic.file
          |> File.stream!()
          |> Enum.count()

        %{diagnostic | position: {1, 0, num_lines + 1, 0}}

      true ->
        diagnostic
    end
  end
end
