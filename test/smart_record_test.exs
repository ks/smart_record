defmodule SmartRecordTest do
  use ExUnit.Case
  doctest SmartRecord

  test "greets the world" do
    assert SmartRecord.hello() == :world
  end
end
