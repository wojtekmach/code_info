defmodule CodeInfoTest do
  use ExUnit.Case, async: true

  test "it works" do
    info =
      CodeInfo.fetch(
        Version,
        [:doc, functions: [:signature], types: [:spec_string]]
      )

    IO.inspect(info, printable_limit: 50)
  end
end
