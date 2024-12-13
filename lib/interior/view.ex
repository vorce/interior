defmodule Interior.View do
  @moduledoc false
  alias Interior.Classifier

  @type t :: %{
          version: String.t(),
          main_app: app,
          classifier: Classifier.t(),
          unclassified_modules: MapSet.t(module),
          module_to_app: %{module => app},
          external_deps: MapSet.t(module)
        }

  @type app :: atom

  @spec build(app) :: t
  def build(main_app) do
    classifier = classify(main_app)

    %{
      version: unquote(Mix.Project.config()[:version]),
      main_app: main_app,
      classifier: classifier,
      unclassified_modules: unclassified_modules(main_app, classifier.modules),
    }
  end

  @spec drop_app(t, atom) :: t
  def drop_app(view, app) do
    classifier = Classifier.delete(view.classifier, app)
    %{view | classifier: classifier}
  end

  defp classify(main_app) do
    main_app_modules = app_modules(main_app)
    main_app_boundaries = load_app_boundaries(main_app_modules)

    Classifier.classify(Classifier.new(), main_app_modules, main_app_boundaries)
  end

  defp load_app_boundaries(modules) do
    for module <- modules, boundary = Interior.Definition.get(module) do
      Map.merge(boundary, %{
        name: module
      })
    end
  end

  defp unclassified_modules(main_app, classified_modules) do
    for module <- app_modules(main_app),
        not Map.has_key?(classified_modules, module),
        not Interior.protocol_impl?(module),
        into: MapSet.new(),
        do: module
  end

  @doc false
  @spec app_modules(Application.app()) :: [module]
  def app_modules(app),
    # we're currently supporting only Elixir modules
    do: Enum.filter(Application.spec(app, :modules) || [], &String.starts_with?(Atom.to_string(&1), "Elixir."))
end
