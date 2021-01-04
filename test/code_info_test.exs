defmodule CodeInfoTest do
  use ExUnit.Case, async: true

  test "get/2" do
    info =
      CodeInfo.get(
        Version,
        [:doc, functions: [:signature], types: [:spec_string]]
      )

    IO.inspect(info, printable_limit: 50)
  end
end
