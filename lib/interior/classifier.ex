defmodule Interior.Classifier do
  @moduledoc false

  @type t :: %{interiors: %{Interior.name() => Interior.t()}, modules: %{module() => Interior.name()}}

  @spec new :: t
  def new, do: %{interiors: %{}, modules: %{}}

  @spec delete(t, atom) :: t
  def delete(classifier, app) do
    interiors_to_delete =
      classifier.interiors
      |> Map.values()
      |> Stream.filter(&(&1.app == app))
      |> Enum.map(& &1.name)

    interiors = Map.drop(classifier.interiors, interiors_to_delete)

    modules =
      for {_, interior} = entry <- classifier.modules,
          Map.has_key?(interiors, interior),
          do: entry,
          into: %{}

    %{classifier | interiors: interiors, modules: modules}
  end

  @spec classify(t, [module], [Interior.t()]) :: t
  def classify(classifier, modules, interiors) do
    trie = build_trie(interiors)

    classifier = %{
      classifier
      | interiors:
          trie
          |> interiors()
          |> Enum.into(classifier.interiors, &{&1.name, &1})
    }

    for module <- modules,
        interior = find_interior(trie, module),
        reduce: classifier do
      classifier -> Map.update!(classifier, :modules, &Map.put(&1, module, interior.name))
    end
  end

  defp interiors(trie, ancestors \\ []) do
    ancestors = if is_nil(trie.interior), do: ancestors, else: [trie.interior.name | ancestors]

    child_boundaries =
      trie.children
      |> Map.values()
      |> Enum.flat_map(&interiors(&1, ancestors))

    if is_nil(trie.interior),
      do: child_boundaries,
      else: [trie.interior | child_boundaries]
  end

  defp build_trie(interiors), do: Enum.reduce(interiors, new_trie(), &add_interior(&2, &1))

  defp new_trie, do: %{interior: nil, children: %{}}

  defp find_interior(trie, module) when is_atom(module) do
    find_interior(trie, Module.split(module))
  end

  defp find_interior(_trie, []), do: nil

  defp find_interior(trie, [part | rest]) do
    case Map.fetch(trie.children, part) do
      {:ok, child_trie} -> find_interior(child_trie, rest) || child_trie.interior
      :error -> nil
    end
  end

  defp add_interior(trie, interior),
    do: add_interior(trie, Module.split(interior.name), interior)

  defp add_interior(trie, [], interior), do: %{trie | interior: interior}

  defp add_interior(trie, [part | rest], interior) do
    Map.update!(
      trie,
      :children,
      fn children ->
        children
        |> Map.put_new_lazy(part, &new_trie/0)
        |> Map.update!(part, &add_interior(&1, rest, interior))
      end
    )
  end
end
