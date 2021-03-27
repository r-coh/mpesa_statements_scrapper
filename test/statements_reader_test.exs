defmodule StatementsReaderTest do
  use ExUnit.Case
  doctest StatementsReader

  test "greets the world" do
    assert StatementsReader.hello() == :world
  end
end
