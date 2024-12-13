defmodule Basic.Qux do
  use Interior, restricts: [{:all, except: [Meh]}]

  defmodule Meh do
    def allowed, do: ""
  end

  defmodule Nah do
    def not_allowed, do: ""
  end
end
