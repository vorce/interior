defmodule Interior do
  @moduledoc """
  Documentation for `Interior`.
  """

  @type t :: %{
          name: name,
          restricts: [module] | [{:all, except: [module]}] | [{:all, []}],
          file: String.t(),
          line: pos_integer,
          app: atom,
          errors: [term]
        }

  @type view :: map

  @type name :: module

  @type error :: {:invalid_reference, reference_error}

  @type dep_error :: %{name: Interior.name(), file: String.t(), line: pos_integer}

  @type reference_error :: %{
          type: :forbidden,
          from_module: module,
          interior: t(),
          reference: Interior.Mix.Xref.entry()
        }

  defmacro __using__(opts), do: Interior.Definition.generate(opts, __CALLER__)

  @spec view(atom) :: view
  def view(app), do: Interior.View.build(app)

  @doc """
  Returns definitions of all boundaries of the main app.

  You shouldn't access the data in this result directly, as it may change significantly without warnings. Use exported
  functions of this module to acquire the information you need.
  """
  @spec all(view) :: [t]
  def all(view),
    do: view.classifier.boundaries |> Map.values() |> Enum.filter(&(&1.app == view.main_app))

  @doc "Returns the definition of the given boundary."
  @spec fetch!(view, name) :: t
  def fetch!(view, name), do: Map.fetch!(view.classifier.interiors, name)

  @doc "Returns the definition of the given boundary."
  @spec fetch(view, name) :: {:ok, t} | :error
  def fetch(view, name), do: Map.fetch(view.classifier.interiors, name)

  @doc "Returns the definition of the given boundary."
  @spec get(view, name) :: t | nil
  def get(view, name), do: Map.get(view.classifier.interiors, name)

  @doc "Returns definition of the boundary to which the given module belongs."
  @spec for_module(view, module) :: t | nil
  def for_module(view, module) do
    with boundary when not is_nil(boundary) <- Map.get(view.classifier.modules, module),
         do: fetch!(view, boundary)
  end

  @doc "Returns the collection of unclassified modules."
  @spec unclassified_modules(view) :: MapSet.t(module)
  def unclassified_modules(view), do: view.unclassified_modules

  @doc "Returns all boundary errors."
  @spec errors(view, Enumerable.t()) :: [error]
  def errors(view, references), do: Interior.Checker.errors(view, references)

  @doc "Returns the application of the given module."
  @spec app(view, module) :: atom | nil
  def app(view, module), do: Map.get(view.module_to_app, module)

  @doc "Returns true if the module is an implementation of some protocol."
  @spec protocol_impl?(module) :: boolean
  def protocol_impl?(module), do: function_exported?(module, :__impl__, 1)

  defmodule Error do
    defexception [:message, :file, :line]
  end
end
