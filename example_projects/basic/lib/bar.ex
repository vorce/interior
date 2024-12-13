defmodule Basic.Bar do
  use Interior, restricts: [Private]
  def hello!(), do: "hi"

  def should_work, do: Basic.Bar.Private.Hello.world()
end
