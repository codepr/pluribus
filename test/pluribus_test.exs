defmodule PluribusTest do
  use ExUnit.Case
  doctest Pluribus

  test "greets the world" do
    assert Pluribus.hello() == :world
  end
end
