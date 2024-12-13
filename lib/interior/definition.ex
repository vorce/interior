# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Interior.Definition do
  @moduledoc false

  def generate(opts, env) do
    opts =
      opts
      # This ensures that alias references passed to `use Interior` (e.g. restricts) are not
      # treated as dependencies (neither compile-time nor runtime) by the Elixir compiler.
      #
      # For example, invoking `use Interior, restricts: [Internal]` in `MySystemWeb` won't add a
      # dependency from `MySystemWeb` to `MySystemWeb.Internal`. We can do this safely here since we're not
      # injecting any calls to the modules referenced in `opts`.
      |> Macro.prewalk(fn term ->
        with {:__aliases__, _, _} <- term,
             do: Macro.expand(term, %{env | function: {:interior, 1}, lexical_tracker: nil})
      end)
      |> Enum.map(fn opt ->
        with {key, references} when key in ~w/restricts/a and is_list(references) <- opt,
             do: {key, expand_references(references)}
      end)

    pos = Macro.escape(%{file: env.file, line: env.line})

    quote bind_quoted: [opts: opts, app: Keyword.fetch!(Mix.Project.config(), :app), pos: pos] do
      @opts opts
      @pos pos
      @app app

      # Definition will be injected before compile, because we need to check if this module is
      # a protocol, which we can only do right before the module is about to be compiled.
      @before_compile Interior.Definition
    end
  end

  defp expand_references(references) do
    Enum.flat_map(
      references,
      fn
        reference ->
          case Macro.decompose_call(reference) do
            {parent, :{}, children} -> Enum.map(children, &Module.concat(parent, &1))
            _ -> [reference]
          end
      end
    )
  end

  @doc false
  defmacro __before_compile__(_) do
    quote do
      Module.register_attribute(__MODULE__, Interior, persist: true, accumulate: false)

      protocol? = Module.defines?(__MODULE__, {:__impl__, 1}, :def)
      mix_task? = String.starts_with?(inspect(__MODULE__), "Mix.Tasks.")

      Module.put_attribute(
        __MODULE__,
        Interior,
        %{
          opts: @opts,
          pos: @pos,
          app: @app,
          protocol?: protocol?,
          mix_task?: mix_task?
        }
      )
    end
  end

  def get(interior) do
    with definition when not is_nil(definition) <- definition(interior) do
      normalize(definition.app, interior, definition.opts, definition.pos)
    end
  end

  defp definition(interior) do
    with true <- :code.get_object_code(interior) != :error,
         [definition] <- Keyword.get(interior.__info__(:attributes), Interior),
         do: definition,
         else: (_ -> nil)
  end

  @doc false
  def normalize(app, boundary, definition, pos \\ %{file: nil, line: nil}) do
    definition
    |> normalize!(app, pos)
    |> normalize_restricts(boundary)
  end

  defp normalize!(user_opts, app, pos) do
    defaults()
    |> Map.merge(project_defaults(user_opts))
    |> Map.merge(%{file: pos.file, line: pos.line, app: app})
    |> merge_user_opts(user_opts)
  end

  defp merge_user_opts(definition, user_opts) do
    user_opts =
      case Keyword.get(user_opts, :ignore?) do
        nil -> user_opts
        value -> Config.Reader.merge([check: [in: not value, out: not value]], user_opts)
      end

    user_opts = Map.new(user_opts)
    valid_keys = ~w/restricts/a

    definition
    |> Map.merge(Map.take(user_opts, valid_keys))
    |> add_errors(
      user_opts
      |> Map.drop(valid_keys)
      |> Enum.map(fn {key, value} -> {:unknown_option, name: key, value: value} end)
    )
  end

  defp normalize_restricts(%{restricts: :all} = definition, _interior),
    do: %{definition | restricts: [{:all, []}]}

  defp normalize_restricts(%{restricts: [{:all, except: exceptions}]} = definition, interior) do
    %{
      definition
      | restricts: [
          {:all,
           except: Enum.map(exceptions, fn exception -> Module.concat(interior, exception) end)}
        ]
    }
  end

  defp normalize_restricts(definition, interior) do
    update_in(
      definition.restricts,
      fn restricts -> Enum.map(restricts, &normalize_restrict(interior, &1)) end
    )
  end

  defp normalize_restrict(interior, restrict) when is_atom(restrict),
    do: Module.concat(interior, restrict)

  defp normalize_restrict(interior, {restrict, opts}),
    do: {Module.concat(interior, restrict), opts}

  defp defaults do
    %{
      errors: []
    }
  end

  defp project_defaults(user_opts) do
    if user_opts[:check][:out] == false do
      %{}
    else
      (Mix.Project.config()[:interior][:default] || [])
      |> Keyword.take(~w/type check/a)
      |> Map.new()
    end
  end

  defp add_errors(definition, errors) do
    errors = Enum.map(errors, &full_error(&1, definition))
    update_in(definition.errors, &Enum.concat(&1, errors))
  end

  defp full_error(tag, definition) when is_atom(tag), do: full_error({tag, []}, definition)

  defp full_error({tag, data}, definition),
    do: {tag, data |> Map.new() |> Map.merge(Map.take(definition, ~w/file line/a))}
end
