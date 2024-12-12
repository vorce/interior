defmodule InteriorTest do
  use ExUnit.Case
  doctest Interior

  test "greets the world" do
    assert Interior.hello() == :world
  end
end
