defmodule CodeInfoTest do
  use ExUnit.Case, async: true

  test "it works" do
    IO.inspect(CodeInfo.info(Version), printable_limit: 50)
  end
end
