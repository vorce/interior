defmodule Basic.Baz do
  use Interior, restricts: :all

  defmodule Inner do
    def foo, do: ""
  end

  def heh, do: ""
end
