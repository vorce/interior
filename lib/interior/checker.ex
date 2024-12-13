# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule Interior.Checker do
  @moduledoc false

  def errors(view, references) do
    forbidden_references(view, references)
  end

  defp forbidden_references(view, references) do
    references
    |> Enum.map(fn reference ->
      %{
        reference: reference,
        interior: Interior.for_module(view, reference.to)
      }
    end)
    |> Enum.reject(fn data ->
      is_nil(data.interior)
    end)
    |> Enum.flat_map(&check_forbidden_reference/1)
  end

  defp check_forbidden_reference(data) do
    from = data.reference.from
      Enum.flat_map(data.interior.restricts, fn restricted ->
        if forbidden_reference?(data.reference.from, data.reference.to, restricted, data.interior) do
          [{:invalid_reference,
          %{
            type: :forbidden,
            from_module: from,
            interior: data.interior,
            reference: data.reference
          }}]
        else
          []
        end
      end)
  end

  defp forbidden_reference?(reference_from, reference_to, {:all, [except: exceptions]}, interior) do
    if within_interior?(reference_from, interior) or reference_to in exceptions do
      false
    else
      String.starts_with?(to_string(reference_to), to_string(interior.name) <> ".")
    end
  end

  defp forbidden_reference?(reference_from, reference_to, {:all, []}, interior) do
    String.starts_with?(to_string(reference_to), to_string(interior.name) <> ".") and not within_interior?(reference_from, interior)
  end

  defp forbidden_reference?(reference_from, reference_to, restricted, interior) do
    String.starts_with?(to_string(reference_to), to_string(restricted)) and not within_interior?(reference_from, interior)
  end

  defp within_interior?(reference_from, interior) do
    String.starts_with?(to_string(reference_from), to_string(interior.name))
  end
end
